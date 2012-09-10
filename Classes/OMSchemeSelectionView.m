//
//  OMSchemeSelectionView.m
//  OMMiniXcode
//
//  Created by Ole Zorn on 10.09.12.
//
//

#import "OMSchemeSelectionView.h"

@implementation OMSchemeSelectionView

@synthesize popUpButton=_popUpButton, tag=_tag, spinner=_spinner;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		_popUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width - 20, 20)];
		_popUpButton.autoresizingMask = NSViewWidthSizable;
		
		[_popUpButton setBezelStyle:NSTexturedRoundedBezelStyle];
		[[_popUpButton cell] setControlSize:NSSmallControlSize];
		[_popUpButton setFont:[NSFont systemFontOfSize:11.0]];
		[self addSubview:_popUpButton];
		
		_spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(NSMaxX(self.bounds) - 16, 2, 16, 16)];
		[_spinner setControlSize:NSSmallControlSize];
		_spinner.autoresizingMask = NSViewMinXMargin;
		[_spinner setStyle:NSProgressIndicatorSpinningStyle];
		[_spinner setDisplayedWhenStopped:NO];
		[self addSubview:_spinner];
    }
    return self;
}

- (BOOL)isOpaque
{
	return NO;
}

- (NSView *)hitTest:(NSPoint)aPoint
{
	//Ignore mouse events for the spinner...
	return [self.popUpButton hitTest:[self convertPoint:aPoint fromView:self.superview]];
}

- (void)dealloc
{
	[_popUpButton release];
	[_spinner release];
	[super dealloc];
}

@end
