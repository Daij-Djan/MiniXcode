//
//  OMMiniXcode.h
//  OMMiniXcode
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class OMSchemeSelectionView;

@interface OMMiniXcode : NSObject {
    NSImage *_errorImage;
    NSImage *_warningImage;
    NSImage *_analyzerResultImage;
    NSImage *_successImage;
}

- (OMSchemeSelectionView *)schemePopUpButtonContainerForWindow:(NSWindow *)window;
- (NSPopUpButton *)schemePopUpButtonForWindow:(NSWindow *)window;

@end

