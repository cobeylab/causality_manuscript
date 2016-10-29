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
    webView.frameLoadDelegate = self;
    
    NSArray * args = [[NSProcessInfo processInfo] arguments];
    
    NSString * path = [args objectAtIndex:1];
    NSLog(@"%@", path);
    NSURL * url = [NSURL fileURLWithPath:path];
    NSLog(@"%@", url);
    
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(saveAndTerminate) userInfo:nil repeats:NO];
}

- (void)saveAndTerminate
{
    NSArray * args = [[NSProcessInfo processInfo] arguments];
    
    WebFrameView * frameView = [[webView mainFrame] frameView];
    NSView<WebDocumentView> * docView = [frameView documentView];
    
    NSString * extension = [[args objectAtIndex:2] pathExtension];
    if([extension isEqualToString:@"pdf"]) {
        NSData * pdfData = [docView dataWithPDFInsideRect:[docView frame]];
        [pdfData writeToFile:[args objectAtIndex:2] atomically:YES];
    }
    else if([extension isEqualToString:@"eps"]) {
        NSData * epsData = [docView dataWithEPSInsideRect:[docView frame]];
        [epsData writeToFile:[args objectAtIndex:2] atomically:YES];
    }
    else {
        NSLog(@"Unknown file format %@", extension);
    }
    
    [[NSApplication sharedApplication] terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

@end
