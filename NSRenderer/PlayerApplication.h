//
//  AppController.h
//  QuartzComposerPlayer
//
//  Created by vade on 6/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <Quartz/Quartz.h>
#import <CoreVideo/CoreVideo.h>


#define kRendererEventMask (NSLeftMouseDownMask | NSLeftMouseDraggedMask | NSLeftMouseUpMask | NSRightMouseDownMask | NSRightMouseDraggedMask | NSRightMouseUpMask | NSOtherMouseDownMask | NSOtherMouseUpMask | NSOtherMouseDraggedMask | NSKeyDownMask | NSKeyUpMask | NSFlagsChangedMask | NSScrollWheelMask | NSTabletPointMask | NSTabletProximityMask)

@interface PlayerApplication : NSApplication
{
}

- (void) updateRenderView:(NSNotification *) notification;
- (CVReturn)displayLinkRenderCallback:(const CVTimeStamp *)timeStamp;
- (IBAction) changeDisplayChoice:(id)sender;

@end
