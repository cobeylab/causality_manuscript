//
//  AppDelegate.m
//  html2pdf
//
//  Created by Edward Baskerville on 1/3/16.
//  Copyright © 2016 Ed Baskerville. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSArray * args = [[NSProcessInfo processInfo] arguments];
    
    NSString * path = [args objectAtIndex:1];
    NSImage * image = [[NSImage alloc] initWithContentsOfFile:path];
//    NSLog(@"image size: %@", NSStringFromSize([image size]));
//    [imageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.window setContentSize:image.size];
    [imageView setFrameOrigin:NSZeroPoint];
    [imageView setFrameSize:image.size];
    [imageView setBoundsSize:image.size];
    imageView.image = image;
    [[self.window contentView] setNeedsDisplay:YES];
//    NSLog(@"image size: %@", NSStringFromSize([image size]));
//    NSLog(@"window rect: %@", NSStringFromRect(self.window.frame));
//    NSLog(@"content bounds: %@", NSStringFromRect([self.window.contentView bounds]));
//    NSLog(@"content frame: %@", NSStringFromRect([self.window.contentView frame]));
//    NSLog(@"view bounds: %@", NSStringFromRect([imageView bounds]));
//    NSLog(@"view frame: %@", NSStringFromRect([imageView frame]));
//    NSLog(@"view visibleRect: %@", NSStringFromRect([imageView visibleRect]));
    
    [NSTimer scheduledTimerWithTimeInterval:0.00 target:self selector:@selector(saveAndTerminate) userInfo:nil repeats:NO];
}

- (void)saveAndTerminate
{
    NSArray * args = [[NSProcessInfo processInfo] arguments];
//    NSLog(@"view bounds: %@", NSStringFromRect([imageView bounds]));
    NSData * epsData = [self.window.contentView dataWithEPSInsideRect:[self.window.contentView bounds]];
    [epsData writeToFile:[args objectAtIndex:2] atomically:YES];
    
    [[NSApplication sharedApplication] terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

@end
