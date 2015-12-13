//
//  AppController.m
//  QuartzComposerPlayer
//
//  Created by vade on 6/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PlayerApplication.h"
#import <OpenGL/CGLMacro.h>

#pragma mark --- Display Link Callback ---
CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,const CVTimeStamp *inNow,const CVTimeStamp *inOutputTime,CVOptionFlags flagsIn,CVOptionFlags *flagsOut,void *displayLinkContext)
{
	CVReturn error = [(__bridge PlayerApplication*) displayLinkContext displayLinkRenderCallback:inOutputTime];
	return error;
}


@interface PlayerApplication ()
{
    CVDisplayLinkRef displayLink;
}

@property (atomic, readwrite, strong) NSOpenGLContext* openGLContext;
@property (atomic, readwrite, strong) QCRenderer* mainRenderer;

// this should probably be an array of N items for each model no?
@property (atomic, readwrite, strong) NSMutableArray* modelRenderers;

// UI Shit
@property (atomic, readwrite, strong) IBOutlet QCCompositionParameterView * paramView;
@property (atomic, readwrite, strong) IBOutlet NSView* openGLView;
@property (atomic, readwrite, strong) IBOutlet NSWindow* renderWindow;
@property (atomic, readwrite, strong) IBOutlet NSPopUpButton* fullscreenPopup;


@property (atomic, readwrite, assign) NSSize screenSize;
@property (atomic, readwrite, assign) NSTimeInterval startTime;

@end


@implementation PlayerApplication

- (void) initDisplayLink
{
    CVReturn            error = kCVReturnSuccess;
    CGDirectDisplayID   displayID = CGMainDisplayID();
	
    error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    if(error)
    {
        NSLog(@"DisplayLink created with error:%d", error);
        displayLink = NULL;
        return;
    }
	
    error = CVDisplayLinkSetOutputCallback(displayLink, MyDisplayLinkCallback, (__bridge void *)(self));
	if(error)
    {
        NSLog(@"DisplayLink could not link to callback, error:%d", error);
        displayLink = NULL;
        return;
    }
		
	CVDisplayLinkStart(displayLink);	
	
	if(!CVDisplayLinkIsRunning(displayLink))
	{
		NSLog(@"DisplayLink is not running - it should be. ");
	}
}

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification 
{
    self.modelRenderers = [[NSMutableArray alloc] init];
    
	[self.paramView setDrawsBackground:NO];

	//If no composition file was dropped on the application's icon, we need to ask the user for one
		
//	NSMutableArray* holdingArray = [[NSMutableArray alloc] init];
//
//	for(NSScreen* screen in [NSScreen screens])
//	{
//		if([[screen deviceDescription] valueForKey:@"NSDeviceIsScreen"])
//		{
//			NSLog(@"screenName: %@", [screen screenName]);
//			[holdingArray addObject:[screen screenName]];
//		}
//	}
//	[self setScreenNames:holdingArray];
//	[holdingArray release];
	
	// open gl initting
	GLint value = 1;
	NSOpenGLPixelFormatAttribute attributes[] = 
	{
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers, 1,
		NSOpenGLPFASamples, 4,
		(NSOpenGLPixelFormatAttribute) 0
	};
	NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	
	self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
	if(self.openGLContext == nil)
	{
		NSLog(@"Could not init with Multisample Antialiasing - creating fallback context");
		
		NSOpenGLPixelFormatAttribute attributes[] = 
		{
			NSOpenGLPFADoubleBuffer,
			NSOpenGLPFAAccelerated,
			NSOpenGLPFADepthSize, 24,
			(NSOpenGLPixelFormatAttribute) 0
		};
		
		format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
		self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];

		if(self.openGLContext == nil)
		{
			NSLog(@"Could not create fallback OpenGL Context - bailing");
			[NSApp terminate:nil];
		}
	}	
	
	self.screenSize = self.openGLView.frame.size; //CGDisplayPixelsWide(kCGDirectMainDisplay);
	
	[self.openGLContext setView:self.openGLView];
	[self.openGLContext setValues:&value forParameter:kCGLCPSwapInterval];
	
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateRenderView:) name:NSViewFrameDidChangeNotification object:self.openGLView];

	[self initDisplayLink];
}

- (void) renderWithEvent:(NSEvent*)event
{
    //Render a frame
    CGLContextObj cgl_ctx = [self.openGLContext CGLContextObj];
    CGLLockContext(cgl_ctx);

    // lazily init our main renderer
    
    //Create the QuartzComposer Renderer with that OpenGL context and the specified composition file
    
    // TODO LOAD FROM OUR APP BUNDLE YO

    if(self.mainRenderer == nil)
    {
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"MainRenderer" ofType:@"qtz"];

        NSString* modelFilePath = [[NSBundle mainBundle] pathForResource:@"ModelRenderer" ofType:@"qtz"];

        self.mainRenderer = [[QCRenderer alloc] initWithOpenGLContext:self.openGLContext pixelFormat:self.openGLContext.pixelFormat file:filePath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.paramView setCompositionRenderer:self.mainRenderer];
        });
        
        if(self.mainRenderer == nil)
        {
            NSLog(@"Cannot create QCRenderer");
            [NSApp terminate:nil];
        }
        
        // Since we havent loaded our Main Renderer we also havent loaded our models yet. Lets load those motherfuckers
        
        NSString* modelPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Models"];
        
        NSDirectoryEnumerator* modelEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:modelPath] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) {
            
            return YES;
            
        }];
        
        for (NSURL* aModelURL in modelEnumerator)
        {
            NSString* aModelPath = [aModelURL path];
            
            QCRenderer* aModelRenderer = [[QCRenderer alloc] initWithOpenGLContext:self.openGLContext pixelFormat:self.openGLContext.pixelFormat file:modelFilePath];

            if(aModelRenderer == nil)
            {
                NSLog(@"Cannot create QCRenderer");
                [NSApp terminate:nil];
            }

            [aModelRenderer setValue:aModelPath forInputKey:@"modelPath"];
            
            // preload the fuckers
            if(![aModelRenderer renderAtTime:0 arguments:nil])
            {
                NSLog(@"unable to preload");
            }
            [self.modelRenderers addObject:aModelRenderer];
            
            NSLog(@"Model Path %@", aModelPath);
        }
    }
    
    
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	NSPoint mouseLocation;
	NSMutableDictionary* arguments;
	
	//Let's compute our local time
	if(_startTime == 0)
	{
		_startTime = time;
		time = 0;
	}
	else
		time -= _startTime;
	
	//We setup the arguments to pass to the composition (normalized mouse coordinates and an optional event)
/*	mouseLocation = [NSEvent mouseLocation];
	mouseLocation.x /= _screenSize.width;
	mouseLocation.y /= _screenSize.height;
*/
	mouseLocation = [self.renderWindow mouseLocationOutsideOfEventStream];
	mouseLocation.x /= self.renderWindow.frame.size.width;
	mouseLocation.y /= self.renderWindow.frame.size.height;
	arguments = [NSMutableDictionary dictionaryWithObject:[NSValue valueWithPoint:mouseLocation] forKey:QCRendererMouseLocationKey];
	if(event)
		[arguments setObject:event forKey:QCRendererEventKey];
	
	if(![self.mainRenderer renderAtTime:time arguments:arguments])
		NSLog(@"Rendering failed at time %.3fs", time);
	
    
    // get the resulting value from our activeModel output
    NSNumber* activeModel = [self.mainRenderer valueForOutputKey:@"activeModel"];
    if(activeModel.floatValue > 0.0 )
    {
        NSInteger modelIndex = (floor([activeModel integerValue]));
        
        modelIndex = modelIndex % self.modelRenderers.count;
        
        if(![self.modelRenderers[modelIndex] renderAtTime:time arguments:arguments])
        {
            NSLog(@"Rendering failed at time %.3fs", time);

        }
        
        //        NSLog(@"Active Model %@", activeModel);
    }
    
    
	//Flush the OpenGL context to display the frame on screen
	[self.openGLContext flushBuffer];
	CGLUnlockContext(cgl_ctx);
}

- (CVReturn)displayLinkRenderCallback:(const CVTimeStamp *)timeStamp
{
    
    @autoreleasepool
    {
        CVReturn rv = kCVReturnError;
        {
            [self renderWithEvent:[NSApp currentEvent]];
            rv = kCVReturnSuccess;
        }
        
        return rv;
    }
}


- (void) _render:(NSTimer*)timer
{
	//Simply call our rendering method, passing no event to the composition
	[self renderWithEvent:nil];
}

- (void) updateRenderView:(NSNotification *) notification
{
	CGLContextObj cgl_ctx = [_openGLContext CGLContextObj];
	CGLLockContext(cgl_ctx);
	[_openGLContext update];
	
	NSRect mainRenderViewFrame = [self.openGLView frame];
	
	glViewport(0, 0, mainRenderViewFrame.size.width, mainRenderViewFrame.size.height);
	glClear(GL_COLOR_BUFFER_BIT);
	
	[_openGLContext flushBuffer];
	CGLUnlockContext(cgl_ctx);
	
	self.screenSize = self.openGLView.frame.size;
}
	
-(IBAction) changeDisplayChoice:(id)sender
{
	BOOL wasRunningOnEntry = CVDisplayLinkIsRunning(displayLink);
	
	if(wasRunningOnEntry)
		CVDisplayLinkStop(displayLink);
	
	CGLContextObj cgl_ctx = [_openGLContext CGLContextObj]; 
	CGLLockContext(cgl_ctx);
	
	switch ([sender selectedColumn])
	{
            
		// FullScreen
		case 0:
        {
			NSLog(@"Fullscreen selected");
			
			[self.fullscreenPopup setEnabled:NO];
			
			NSMutableDictionary * fullscreenDictionary = [NSMutableDictionary dictionary];
			[fullscreenDictionary setObject:[NSNumber numberWithBool:0] forKey:NSFullScreenModeAllScreens];	
			[fullscreenDictionary setObject:[NSNumber numberWithInt:NSNormalWindowLevel] forKey:NSFullScreenModeWindowLevel];	

			[self.renderWindow orderOut:self];
			
			NSInteger screenChoice = [self.fullscreenPopup indexOfSelectedItem];
			if (screenChoice >= [[NSScreen screens] count])
			{
				NSLog(@"Unable to use screenChoice");
				screenChoice = 0;
			}
			NSScreen* renderScreen = [[NSScreen screens] objectAtIndex:screenChoice];
			
			[self.openGLView enterFullScreenMode:renderScreen withOptions:fullscreenDictionary];
			
			break;
        }
		case 1:
        {
			NSLog(@"Fixed Window selected");
			break;
        }
		case 2:
        {
			NSLog(@"Free Window selected");
			
			if([self.openGLView isInFullScreenMode])
			{
				[self.fullscreenPopup setEnabled:YES];
				[self.renderWindow orderFront:self];
				[self.openGLView exitFullScreenModeWithOptions:nil];
			}
			
			break;
        }
		default:
        {
			NSLog(@"changeDisplayChoice: Unrecognised option");
			break;
        }
	}
	
	[self.openGLContext update];
	
	glViewport(0, 0, [self.openGLView frame].size.width, [self.openGLView frame].size.height);		// resize GL viewport to match our new frame
	[self.openGLContext flushBuffer];
	CGLUnlockContext(cgl_ctx);
	
	if(wasRunningOnEntry)
		CVDisplayLinkStart(displayLink);
}


- (void) applicationWillTerminate:(NSNotification*)aNotification 
{
	CVDisplayLinkStop(displayLink);
	CVDisplayLinkRelease(displayLink);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// releases the _renderer as well.
	[self.paramView setCompositionRenderer:nil];
	
	
	//Destroy the OpenGL context
	[self.openGLContext clearDrawable];
	
}

@end