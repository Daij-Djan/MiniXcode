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
	NSInteger _tag;
}

@property (nonatomic, retain) NSPopUpButton *popUpButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, assign) NSInteger tag;

@end
