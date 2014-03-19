//
//  OMMiniXcode.m
//  OMMiniXcode
//
//  Created by Ole Zorn on 09/07/12.
//  Modified by Dominik Pich
//
//

#import "OMMiniXcode.h"
#import "OMSchemeSelectionView.h"
#import "NSAttributedString+DDConvenience.h"

#define SCHEME_POPUP_BUTTON_CONTAINER_TAG	456
#define SCHEME_POPUP_BUTTON_TAG				457
#define BUILD_PROGRESS_SPINNER_TAG			458

#define kOMMiniXcodeDisableSchemeSelectionInTitleBar	@"OMMiniXcodeDisableSchemeSelectionInTitleBar"

//TODO: Use the actual headers from class-dump

@interface NSObject (IDEKit)
- (void)setActiveRunContext:(id)arg1 andRunDestination:(id)arg2;
- (id)_bestDestinationForScheme:(id)arg1 previousDestination:(id)arg2;
- (id)activeRunDestination;
+ (id)workspaceWindowControllers;
@end


@implementation OMMiniXcode {
    id _schemeView;
}

#pragma mark - lifecycle management

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id sharedPlugin = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (id)init
{
	if (self = [super init]) {
        //observe path
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildProductsLocationDidChange:) name:@"IDEWorkspaceBuildProductsLocationDidChangeNotification" object:nil];
		
        //observer window state
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:nil];
//		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(splitViewDidResizeSubviews:) name:NSSplitViewDidResizeSubviewsNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidEndLiveResize:) name:NSWindowDidEndLiveResizeNotification object:nil];
		
        //observe builds
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildWillStart:) name:@"IDEBuildOperationWillStartNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildDidStop:) name:@"IDEBuildOperationDidStopNotification" object:nil];
		
        //preload our icons
        NSBundle *bundle = [NSBundle bundleForClass:self.class];
        _errorImage = [bundle imageForResource:@"XCBuildErrorIcon"];
        _warningImage = [bundle imageForResource:@"XCBuildWarningIcon"];
        _analyzerResultImage = [bundle imageForResource:@"XCBuildAnalyzerResultIcon"];
        _successImage = [bundle imageForResource:@"XCBuildSuccessIcon"];
        
        //add an entry to toggle 'us' to the view menu
		NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
		if (viewMenuItem) {
			[[viewMenuItem submenu] addItem:[NSMenuItem separatorItem]];
			NSMenuItem *toggleSchemeInTitleBarItem = [[NSMenuItem alloc] initWithTitle:@"Scheme Selection in Title Bar" action:@selector(toggleSchemeInTitleBar:) keyEquivalent:@""];
			[toggleSchemeInTitleBarItem setTarget:self];
			[[viewMenuItem submenu] addItem:toggleSchemeInTitleBarItem];
		}
		
        //catch keydowns on our schemeview
		[NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *event) {
			unsigned short keyCode = [event keyCode];
			if ((keyCode == 26 || keyCode == 28) && [event modifierFlags] & NSControlKeyMask) {
				NSWindow *window = [NSApp keyWindow];
				OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
				NSPopUpButton *popUpButton = schemeView.popUpButton;
				BOOL toolbarVisible = [[window toolbar] isVisible];
				if (schemeView && !toolbarVisible) {
					NSMenuItem *selectedItem = [popUpButton selectedItem];
					if (keyCode == 28) {
						for (NSMenuItem *item in [[[popUpButton menu] itemArray] reverseObjectEnumerator]) {
							if (item.state == NSOnState) {
								selectedItem = item;
								break;
							}
						}
					}
					[[popUpButton menu] popUpMenuPositioningItem:selectedItem atLocation:NSMakePoint(-14, 2) inView:popUpButton];
				} else if (popUpButton) {
					@try {
						NSToolbar *toolbar = [window toolbar];
						if (toolbar.items.count >= 3) {
							NSToolbarItem *schemeItem = [toolbar.items objectAtIndex:2];
							NSView *schemeView = schemeItem.view;
							if (schemeView.subviews.count > 0) {
								NSPathControl *pathControl = (NSPathControl *)[schemeView.subviews objectAtIndex:0];
								if ([pathControl isKindOfClass:[NSPathControl class]] && [pathControl isKindOfClass:NSClassFromString(@"IDEPathControl")]) {
									NSArray *componentCells = [pathControl pathComponentCells];
									if (componentCells.count > 1) {
										NSPathComponentCell *cell = [componentCells objectAtIndex:(keyCode == 26 ? 0 : 1)];
										if ([pathControl respondsToSelector:@selector(popUpMenuForComponentCell:)]) {
											[pathControl performSelector:@selector(popUpMenuForComponentCell:) withObject:cell];
										}
									}
								}
							}
						}
					}
					@catch (NSException *exception) { }
				} else {
					NSBeep();
				}
				return nil;
			}
			return event;
		}];
	}
	return self;
}


- (void)dealloc
{
    //remove all observers
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)toggleSchemeInTitleBar:(id)sender
{
	BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
	titleBarDisabled = !titleBarDisabled;
	[[NSUserDefaults standardUserDefaults] setBool:titleBarDisabled forKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
	
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
			BOOL toolbarVisible = [[window toolbar] isVisible];
			if (schemeView) {
				[schemeView setHidden:titleBarDisabled || toolbarVisible];
			}
		}
	}
	@catch (NSException *exception) { }
}

- (void)selectDestination:(id)sender
{
	NSDictionary *info = [sender representedObject];
	id destination = [info objectForKey:@"destination"];
	id context = [info objectForKey:@"context"];
	@try {
		id runContextManager = [[[NSApp keyWindow] windowController] valueForKeyPath:@"_workspace.runContextManager"];
		[runContextManager setActiveRunContext:context andRunDestination:destination];
	}
	@catch (NSException *exception) { }
}

- (void)selectRunContext:(id)sender
{
	NSDictionary *info = [sender representedObject];
	id context = [info objectForKey:@"context"];
	@try {
		id runContextManager = [[[NSApp keyWindow] windowController] valueForKeyPath:@"_workspace.runContextManager"];
		id bestDestination = [runContextManager _bestDestinationForScheme:context previousDestination:[runContextManager activeRunDestination]];
		[runContextManager setActiveRunContext:context andRunDestination:bestDestination];
	}
	@catch (NSException *exception) { }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(toggleSchemeInTitleBar:)) {
		BOOL toolbarVisible = [[[NSApp keyWindow] toolbar] isVisible];
		BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
		[menuItem setState:disabled ? NSOffState : NSOnState];
		if (toolbarVisible) {
			return NO;
		}
	}
	return YES;
}

- (NSView *)windowTitleViewForWindow:(NSWindow *)window
{
	NSView *windowFrameView = [[window contentView] superview];
	for (NSView *view in windowFrameView.subviews) {
		if ([view isKindOfClass:NSClassFromString(@"DVTDualProxyWindowTitleView")]) {
			return view;
		}
	}
	return nil;
}

- (NSPopUpButton *)schemePopUpButtonForWindow:(NSWindow *)window
{
	OMSchemeSelectionView *container = [self schemePopUpButtonContainerForWindow:window];
	return container.popUpButton;
}

- (OMSchemeSelectionView *)schemePopUpButtonContainerForWindow:(NSWindow *)window
{
	if ([window isKindOfClass:NSClassFromString(@"IDEWorkspaceWindow")]) {
		NSView *windowFrameView = [[window contentView] superview];
		OMSchemeSelectionView *popUpContainerView = [windowFrameView viewWithTag:SCHEME_POPUP_BUTTON_CONTAINER_TAG];
		if (!popUpContainerView) {
			
			CGFloat buttonWidth = 200.0;
//			NSView *titleView = [self windowTitleViewForWindow:window];
//			if (titleView) {
//				buttonWidth = MIN(buttonWidth, titleView.frame.origin.x - 10 - 80);
//			}
			
			popUpContainerView = [[OMSchemeSelectionView alloc] initWithFrame:NSMakeRect(70, windowFrameView.bounds.size.height - 22, buttonWidth + 174, 20)];
			popUpContainerView.tag = SCHEME_POPUP_BUTTON_CONTAINER_TAG;
			popUpContainerView.autoresizingMask = NSViewMinYMargin;
			
			BOOL toolbarVisible = [[window toolbar] isVisible];
			BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
			
			[popUpContainerView setHidden:toolbarVisible || titleBarDisabled];
			[windowFrameView addSubview:popUpContainerView];
			
		}
		return popUpContainerView;
	}
	return nil;
}

#pragma mark - window state & splitview callbacks

- (void)windowDidEndLiveResize:(NSNotification *)notification
{
	NSWindow *window = [notification object];
	NSView *schemeView = [self schemePopUpButtonContainerForWindow:window];
	if (schemeView) {
		double delayInSeconds = 0.0;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self handleResizeOfWindow:window];
		});
	}
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSWindow *window = [notification object];
	if ([window isKindOfClass:NSClassFromString(@"IDEWorkspaceWindow")]) {
		@try {
			NSWindowController *windowController = [window windowController];
			if ([windowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
				id workspace = [windowController valueForKey:@"_workspace"];
				NSNotification *dummyNotification = [NSNotification notificationWithName:@"IDEWorkspaceBuildProductsLocationDidChangeNotification" object:workspace];
				[self buildProductsLocationDidChange:dummyNotification];
			}
		}
		@catch (NSException *exception) { }
	}
}

- (void)handleResizeOfWindow:(NSWindow*)window
{
    NSView *schemeView = [self schemePopUpButtonContainerForWindow:window];
    if (schemeView) {
        BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
        BOOL toolbarVisible = [[window toolbar] isVisible];
        [schemeView setHidden:toolbarVisible || titleBarDisabled];
//        NSView *titleView = [self windowTitleViewForWindow:window];
//        if (titleView) {
//            leftMostWidth = MIN(leftMostWidth, titleView.frame.origin.x - 174);
//        }
//        schemeView.frame = NSMakeRect(schemeView.frame.origin.x, schemeView.frame.origin.y, schemeView.frame.size.width, schemeView.frame.size.height);
    }
}

#pragma mark - build callbacks

- (void)buildWillStart:(NSNotification *)notification
{
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
			if (schemeView) {
                schemeView.spinner.hidden = NO;
                [schemeView resizeSubviewsWithOldSize:schemeView.frame.size];
				[schemeView.spinner startAnimation:nil];

                _schemeView = schemeView;
                [notification.object addObserver:self
                                      forKeyPath:@"percentComplete"
                                         options:0
                                         context:(__bridge void *)(schemeView)];
            }
		}
    }
	@catch (NSException *exception) { }
}

- (void)buildDidStop:(NSNotification *)notification
{
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
			if (schemeView) {
				[schemeView.spinner stopAnimation:nil];
                schemeView.spinner.hidden = YES;
                [schemeView resizeSubviewsWithOldSize:schemeView.frame.size];

                [notification.object removeObserver:self
                                         forKeyPath:@"percentComplete"
                                            context:(__bridge void *)(schemeView)];
                _schemeView = nil;
			}
		}
	}
	@catch (NSException *exception) { }
}

- (void)buildProductsLocationDidChange:(NSNotification *)notification
{
	@try {
		id workspace = [notification object];
		if ([workspace isKindOfClass:NSClassFromString(@"IDEWorkspace")]) {
			NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
			for (NSWindowController *workspaceWindowController in workspaceWindowControllers) {
				id workspaceForWindowController = [workspaceWindowController valueForKey:@"_workspace"];
				if (workspace == workspaceForWindowController) {
					NSPopUpButton *popUpButton = [self schemePopUpButtonForWindow:workspaceWindowController.window];
					NSMenu *menu = [[NSMenu alloc] init];
					[menu setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
					
					id runContextManager = [workspace valueForKey:@"runContextManager"];
					id activeDestination = [runContextManager valueForKey:@"_activeRunDestination"];
					id activeScheme = [runContextManager valueForKey:@"_activeRunContext"];
					NSArray *runContexts = [runContextManager performSelector:@selector(runContexts)];
					for (id scheme in runContexts) {
						NSMenuItem *schemeItem = [[NSMenuItem alloc] initWithTitle:[scheme valueForKey:@"name"] action:@selector(selectRunContext:) keyEquivalent:@""];
						NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:scheme, @"context", nil];
						[schemeItem setRepresentedObject:info];
						if (scheme == activeScheme) {
							[schemeItem setState:NSOnState];
							[schemeItem setTitle:[NSString stringWithFormat:@"%@ | %@", [scheme name], [activeDestination displayName]]];
						} else {
							[schemeItem setState:NSOffState];
						}
						NSArray *destinations = [scheme valueForKey:@"availableRunDestinations"];
						if (destinations.count > 0) {
							NSMenu *submenu = [[NSMenu alloc] initWithTitle:@""];
							[schemeItem setSubmenu:submenu];
							for (id destination in destinations) {
								NSMenuItem *destinationItem = [[NSMenuItem alloc] initWithTitle:[destination valueForKey:@"fullDisplayName"] action:@selector(selectDestination:) keyEquivalent:@""];
								NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:destination, @"destination", scheme, @"context", nil];
								[destinationItem setRepresentedObject:info];
								[destinationItem setTarget:self];
								[destinationItem setState:(destination == activeDestination) ? NSOnState : NSOffState];
								[submenu addItem:destinationItem];
							}
						}
						[schemeItem setTarget:self];
						[menu addItem:schemeItem];
					}
					[menu addItem:[NSMenuItem separatorItem]];
					NSArray *activeSchemeDestinations = [activeScheme valueForKey:@"availableRunDestinations"];
					for (id destination in activeSchemeDestinations) {
						NSMenuItem *destinationItem = [[NSMenuItem alloc] initWithTitle:[destination valueForKey:@"fullDisplayName"] action:@selector(selectDestination:) keyEquivalent:@""];
						NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:destination, @"destination", activeScheme, @"context", nil];
						[destinationItem setRepresentedObject:info];
						[destinationItem setTarget:self];
						[destinationItem setState:(destination == activeDestination) ? NSOnState : NSOffState];
						[menu addItem:destinationItem];
					}
					[popUpButton setMenu:menu];
				}
			}
		}
	}
	@catch (NSException *exception) {
		
	}
}

- (void)build:(id)build progressedForView:(OMSchemeSelectionView*)view {
    id complete = [build valueForKey:@"percentComplete"];
    id log = [build valueForKey:@"buildLog"];
    
    // build progess string
    NSMutableAttributedString *attributedProgress = [[NSMutableAttributedString alloc] init];

    //err
    id number = [log valueForKey:@"totalNumberOfErrors"];
    if([number intValue]) {
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithImage:_errorImage]];
        [attributedProgress addAttribute:NSBaselineOffsetAttributeName value:@(-2) range:NSMakeRange(attributedProgress.length-1, 1)];
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithFormat:@"%@ ", number]];
    }
    
    //warn
    number = [log valueForKey:@"totalNumberOfWarnings"];
    if([number intValue]) {
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithImage:_warningImage]];
        [attributedProgress addAttribute:NSBaselineOffsetAttributeName value:@(-2) range:NSMakeRange(attributedProgress.length-1, 1)];
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithFormat:@"%@ ", number]];
    }

    //analyzer
    number = [log valueForKey:@"totalNumberOfAnalyzerWarnings"];
    id number2 = [log valueForKey:@"totalNumberOfAnalyzerResults"];
    number = @([number intValue]+[number2 intValue]);
    if([number intValue]) {
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithImage:_analyzerResultImage]];
        [attributedProgress addAttribute:NSBaselineOffsetAttributeName value:@(-2) range:NSMakeRange(attributedProgress.length-1, 1)];
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithFormat:@"%@ ", number]];
    }

    //add percentage if != 100
    if([complete intValue]!=100) {
        [attributedProgress appendAttributedString:[NSAttributedString attributedStringWithFormat:@"%d%% ", [complete intValue]]];
    }
    
    view.label.attributedStringValue = attributedProgress;
}

#pragma mark build progress monitor via KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    @try {
        if([keyPath isEqualToString:@"percentComplete"]) {
            [self build:object progressedForView:(__bridge OMSchemeSelectionView *)(context)];
        }
        else {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    }
    @catch (NSException *exception) {

    }
}


@end
