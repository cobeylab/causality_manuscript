//
//  AppDelegate.h
//  html2pdf
//
//  Created by Edward Baskerville on 1/3/16.
//  Copyright © 2016 Ed Baskerville. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WebFrameLoadDelegate>
{
    IBOutlet WebView * webView;
}

@end

