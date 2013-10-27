//
//  OMSchemeSelectionView.h
//  OMMiniXcode
//
//  Created by Ole Zorn on 10.09.12.
//
//

#import <Cocoa/Cocoa.h>

@interface OMSchemeSelectionView : NSView {

	NSPopUpButton *_popUpButton;
	NSProgressIndicator *_spinner;
	NSTextField *_label;
	NSInteger _tag;
}

@property (nonatomic, strong) NSPopUpButton *popUpButton;
@property (nonatomic, strong) NSProgressIndicator *spinner;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, assign) NSInteger tag;

@end
