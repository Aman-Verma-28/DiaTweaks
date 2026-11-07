#import "SidebarNavigation.h"

static const CGFloat DPButtonSize = 28, DPButtonGap = 2, DPAfterLights = 8;

@interface DPNavButton : NSButton
@property (nonatomic, copy) NSString *diaLabel;  // The toolbar control it presses; nil for reload, which changes label.
@end

@implementation DPNavButton
- (NSView *)control {
    NSView *pane = DPNavPane(self.window);
    return self.diaLabel ? DPToolbarControl(pane, self.diaLabel) : DPReloadControl(pane);
}

// Back and forward list the history, as Dia's do.
- (NSMenu *)menuForEvent:(NSEvent *)event { return self.diaLabel ? [self.control menuForEvent:event] : nil; }
@end

static NSImage *DPSymbol(NSString *name, NSString *label) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    return [[NSImage imageWithSystemSymbolName:name accessibilityDescription:label] imageWithSymbolConfiguration:config];
}

static DPNavButton *DPMakeButton(NSString *symbol, NSString *diaLabel, id target) {
    DPNavButton *button = [DPNavButton buttonWithImage:DPSymbol(symbol, diaLabel) target:target action:@selector(press:)];
    button.diaLabel = diaLabel;
    button.bezelStyle = NSBezelStyleAccessoryBarAction;
    button.showsBorderOnlyWhileMouseInside = YES;
    button.imagePosition = NSImageOnly;
    button.contentTintColor = NSColor.secondaryLabelColor;
    [button setAccessibilityLabel:diaLabel];
    return button;
}

// What a view in the window buttons' row shows: its controls, or nothing, like the profile indicator with one profile.
static NSRect DPShownFrame(NSView *view, NSView *row) {
    if (view.hidden || view.alphaValue < 0.01 || NSIsEmptyRect(view.bounds)) return NSZeroRect;
    if ([view isKindOfClass:NSControl.class]) return [view convertRect:view.bounds toView:row];
    NSRect shown = NSZeroRect;
    for (NSView *sub in view.subviews) shown = NSUnionRect(shown, DPShownFrame(sub, row));
    return shown;
}

@implementation DPNavButtons {
    DPNavButton *_sidebar, *_back, *_forward, *_reload;
    BOOL _loading;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _sidebar = DPMakeButton(@"sidebar.left", @"Toggle sidebar", self);
    _back = DPMakeButton(@"arrow.left", @"Go back", self);
    _forward = DPMakeButton(@"arrow.right", @"Go forward", self);
    _reload = DPMakeButton(@"arrow.clockwise", nil, self);
    [_reload setAccessibilityLabel:@"Reload this page"];
    for (NSButton *button in @[_sidebar, _back, _forward, _reload]) [self addSubview:button];
    DPTrackNavView(self);
    return self;
}

// Between the buttons, clicks reach the window buttons, the profile indicator and the window behind.
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return hit == self ? nil : hit;
}

// The sidebar button follows whatever shows on the left of the row, and the others end where the row ends.
- (void)layout {
    [super layout];
    NSView *row = self.superview;
    CGFloat left = 0, right = NSWidth(self.bounds);
    for (NSView *sub in row.subviews) {
        NSRect shown = sub == self ? NSZeroRect : DPShownFrame(sub, row);
        if (NSIsEmptyRect(shown)) continue;
        if (NSMidX(shown) < NSMidX(row.bounds)) left = MAX(left, NSMaxX(shown) + DPAfterLights);
        else right = MIN(right, NSMinX(shown) - DPButtonGap);
    }
    CGFloat y = round(NSMidY(self.bounds) - DPButtonSize / 2), x = right;
    for (NSButton *button in @[_reload, _forward, _back]) {
        x -= DPButtonSize;
        button.frame = NSMakeRect(x, y, DPButtonSize, DPButtonSize);
        x -= DPButtonGap;
    }
    _sidebar.frame = NSMakeRect(left, y, DPButtonSize, DPButtonSize);
    _sidebar.hidden = NSMaxX(_sidebar.frame) > x;  // A sidebar too narrow for all four keeps the ones for the page.
}

- (void)press:(DPNavButton *)sender { [sender.control accessibilityPerformPress]; }

- (void)mirrorPane:(NSView *)pane {
    self.needsLayout = YES;  // What shows beside them, such as the profile indicator, can change with the page's window.
    _back.enabled = [(NSControl *)DPToolbarControl(pane, @"Go back") isEnabled];
    _forward.enabled = [(NSControl *)DPToolbarControl(pane, @"Go forward") isEnabled];
    BOOL loading = DPPaneIsLoading(pane);
    if (loading == _loading) return;
    _loading = loading;
    NSString *label = loading ? @"Stop loading this page" : @"Reload this page";
    _reload.image = DPSymbol(loading ? @"xmark" : @"arrow.clockwise", label);
    [_reload setAccessibilityLabel:label];
}

- (void)viewDidMoveToWindow { DPScheduleNavigationRefresh(); }
- (void)viewDidUnhide { DPScheduleNavigationRefresh(); }
@end

DPNavButtons *DPNavButtonsIn(NSView *row, BOOL create) {
    for (NSView *sub in row.subviews) if ([sub isKindOfClass:DPNavButtons.class]) return (DPNavButtons *)sub;
    if (!create) return nil;
    DPNavButtons *buttons = [[DPNavButtons alloc] initWithFrame:row.bounds];
    [row addSubview:buttons];
    return buttons;
}
