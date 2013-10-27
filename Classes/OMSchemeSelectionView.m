//
//  OMSchemeSelectionView.m
//  OMMiniXcode
//
//  Created by Ole Zorn on 10.09.12.
//
//

#import "OMSchemeSelectionView.h"

@implementation OMSchemeSelectionView

@synthesize popUpButton=_popUpButton, tag=_tag, spinner=_spinner, label=_label;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		_popUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width - 174, 20)];
		_popUpButton.autoresizingMask = NSViewWidthSizable;
		
		[_popUpButton setBezelStyle:NSTexturedRoundedBezelStyle];
		[[_popUpButton cell] setControlSize:NSSmallControlSize];
		[_popUpButton setFont:[NSFont systemFontOfSize:11.0]];
		[self addSubview:_popUpButton];
		
		_spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(NSMaxX(self.bounds) - 170, 2, 16, 16)];
		[_spinner setControlSize:NSSmallControlSize];
		_spinner.autoresizingMask = NSViewMinXMargin;
		[_spinner setStyle:NSProgressIndicatorSpinningStyle];
		[_spinner setDisplayedWhenStopped:NO];
        [_spinner setHidden:YES];
		[self addSubview:_spinner];

        _label = [[NSTextField alloc] initWithFrame:NSMakeRect(NSMaxX(self.bounds) - 170, 2, 170, 16)];
		_label.autoresizingMask = NSViewMinXMargin;
		[_label setBezeled:NO];
		[_label setDrawsBackground:NO];
		[_label setEditable:NO];
        [_label setSelectable:NO];
		[_popUpButton setFont:[NSFont systemFontOfSize:11.0]];
		[self addSubview:_label];
    }
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
	[super resizeSubviewsWithOldSize:oldBoundsSize];
    
	self.popUpButton.frame = NSMakeRect(0, 0, NSMaxX(self.bounds) - 174, NSMaxY(self.bounds));
	self.spinner.frame = NSMakeRect(NSMaxX(self.bounds) - 170, 2, 16, 16);

    CGFloat size = self.spinner.isHidden ? 170 : 150;
	self.label.frame = NSMakeRect(NSMaxX(self.bounds) - size, 2, size, 16);
}

- (BOOL)isOpaque
{
	return NO;
}

- (NSView *)hitTest:(NSPoint)aPoint
{
	//Ignore mouse events for the spinner or the label
	return [self.popUpButton hitTest:[self convertPoint:aPoint fromView:self.superview]];
}


@end
