#import "SidebarNavigation.h"

const CGFloat DPAddressRowHeight = 42;
static const CGFloat DPFieldInset = 6, DPFieldHeight = 34, DPIconSize = 24;

// A click, or a press from VoiceOver, opens Dia's command bar on the address, as ⌘L does.
@interface DPAddressField : NSView
@end

@implementation DPAddressField
- (void)mouseDown:(NSEvent *)event { DPPerformMenuItem(@"Open Command Bar"); }
- (BOOL)isAccessibilityElement { return YES; }
- (NSAccessibilityRole)accessibilityRole { return NSAccessibilityButtonRole; }
- (BOOL)accessibilityPerformPress { return DPPerformMenuItem(@"Open Command Bar"); }
@end

static NSButton *DPIconButton(NSString *symbol, NSString *label, id target, SEL action) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightMedium];
    NSImage *image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label] imageWithSymbolConfiguration:config];
    NSButton *button = [NSButton buttonWithImage:image target:target action:action];
    button.bezelStyle = NSBezelStyleAccessoryBarAction;
    button.showsBorderOnlyWhileMouseInside = YES;
    button.imagePosition = NSImageOnly;
    button.contentTintColor = NSColor.secondaryLabelColor;
    [button setAccessibilityLabel:label];
    return button;
}

// The address in a rounded field like the toolbar's, with buttons to copy it and open the site menu.
@implementation DPAddressRow {
    DPAddressField *_field;
    NSTextField *_text;
    NSButton *_copy, *_site;
    NSImage *_linkImage;
    BOOL _hovered;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    _field = [DPAddressField new];
    _field.wantsLayer = YES;
    _field.layer.cornerRadius = 10;
    _field.layer.cornerCurve = kCACornerCurveContinuous;
    _text = [NSTextField labelWithString:@""];
    _text.font = [NSFont systemFontOfSize:13];
    _text.lineBreakMode = NSLineBreakByTruncatingTail;
    _text.cell.usesSingleLineMode = YES;
    [_field addSubview:_text];
    _copy = DPIconButton(@"link", @"Copy URL", self, @selector(copyURL:));
    _site = DPIconButton(@"slider.horizontal.3", @"Site menu", self, @selector(openSiteMenu:));
    _linkImage = _copy.image;
    for (NSView *view in @[_field, _copy, _site]) [self addSubview:view];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    DPTrackNavView(self);
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }

- (void)updateLayer {
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self->_field.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:self->_hovered ? 0.12 : 0.07].CGColor;
    }];
}

- (void)layout {
    [super layout];
    _field.frame = NSMakeRect(DPFieldInset, 2, MAX(0, NSWidth(self.bounds) - 2 * DPFieldInset), DPFieldHeight);
    CGFloat y = NSMinY(_field.frame) + round((DPFieldHeight - DPIconSize) / 2), right = NSMaxX(_field.frame) - 5;
    _site.frame = NSMakeRect(right - DPIconSize, y, DPIconSize, DPIconSize);
    _copy.frame = NSMakeRect(NSMinX(_site.frame) - DPIconSize, y, DPIconSize, DPIconSize);
    CGFloat textHeight = ceil(_text.intrinsicContentSize.height);
    CGFloat textWidth = NSMinX(_copy.frame) - NSMinX(_field.frame) - 15;
    _text.frame = NSMakeRect(11, round((DPFieldHeight - textHeight) / 2), MAX(0, textWidth), textHeight);
}

- (void)setHovered:(BOOL)hovered {
    _hovered = hovered;
    self.needsDisplay = YES;
}
- (void)mouseEntered:(NSEvent *)event { [self setHovered:YES]; }
- (void)mouseExited:(NSEvent *)event { [self setHovered:NO]; }

// Around the field, clicks reach what's under the row, such as the edge that resizes the sidebar.
- (NSView *)hitTest:(NSPoint)point {
    return NSPointInRect([self convertPoint:point fromView:self.superview], _field.frame) ? [super hitTest:point] : nil;
}

- (void)copyURL:(id)sender {
    if (!DPPerformMenuItem(@"Copy URL")) return;
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightSemibold];
    _copy.image = [[NSImage imageWithSystemSymbolName:@"checkmark" accessibilityDescription:@"Copied"] imageWithSymbolConfiguration:config];
    __weak DPAddressRow *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DPAddressRow *me = weakSelf;
        if (me) me->_copy.image = me->_linkImage;
    });
}

- (void)openSiteMenu:(NSButton *)sender { DPOpenSiteMenu(sender); }

- (void)mirrorPane:(NSView *)pane {
    NSString *address = DPAddressText(pane);
    BOOL empty = address.length == 0;
    NSString *shown = empty ? @"Search or Enter URL…" : address;
    if (![_text.stringValue isEqual:shown]) _text.stringValue = shown;
    _text.textColor = empty ? NSColor.tertiaryLabelColor : NSColor.secondaryLabelColor;
    [_field setAccessibilityLabel:shown];
}

- (void)viewDidMoveToWindow { DPScheduleNavigationRefresh(); }
- (void)viewDidUnhide { DPScheduleNavigationRefresh(); }
@end

DPAddressRow *DPAddressRowIn(NSView *holder, BOOL create) {
    for (NSView *sub in holder.subviews) if ([sub isKindOfClass:DPAddressRow.class]) return (DPAddressRow *)sub;
    if (!create) return nil;
    DPAddressRow *row = [[DPAddressRow alloc] initWithFrame:NSZeroRect];
    [holder addSubview:row];
    return row;
}
