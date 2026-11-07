#import "SidebarNavigation.h"

// The buttons sit in the header's row, where Dia keeps the window buttons, so whatever moves that row, such as Compact
// Sidebar Header, moves them too. The address takes the top of the view the spaces' tabs page through. Its controller sizes the tabs to
// it as it lays out, which comes after the sidebar and every patch on it has placed it, so the room is made just before.

static NSHashTable<NSView *> *DPNavLaidOut;  // Headers and tab holders, to lay out again on a switch.
static char DPHolderKey;

static void DPMakeRoom(NSView *holder) {
    NSView *sidebar = holder.superview;
    if (!DPSubview(holder, DPDiaSidebarViewport) || !DPSubview(sidebar, DPDiaSidebarHeader) || !DPMayAdjust(holder)) return;
    NSRect laidOut = [DPDiaValue(holder, &DPHolderKey, @(holder.frame)) rectValue], frame = laidOut;
    CGFloat inset = DPSidebarNavigationShown() ? MIN(DPAddressRowHeight, NSHeight(laidOut)) : 0;
    frame.size.height -= inset;
    if (sidebar.isFlipped) frame.origin.y += inset;
    DPOverride(holder, &DPHolderKey, @(laidOut), @(frame));
    if (!NSEqualRects(holder.frame, frame)) holder.frame = frame;

    DPAddressRow *row = DPAddressRowIn(sidebar, inset > 0);
    if (!row) return;
    row.hidden = inset == 0;
    row.frame = NSMakeRect(NSMinX(laidOut), sidebar.isFlipped ? NSMinY(laidOut) : NSMaxY(laidOut) - inset, NSWidth(laidOut), inset);
}

static void DPPaging_viewWillLayout(NSViewController *self, SEL _cmd) {
    [DPNavLaidOut addObject:self.view];
    DPMakeRoom(self.view);
    DPCallOriginal(DPPaging_viewWillLayout, self);
}

static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    [DPNavLaidOut addObject:self];
    // The row is the header's stack, which Hide Window Controls takes the window buttons out of.
    NSView *row = DPSubview(self, "NSStackView");
    if (!row) return;
    BOOL shown = DPSidebarNavigationShown();
    DPNavButtons *buttons = DPNavButtonsIn(row, shown);
    if (!buttons) return;
    buttons.hidden = !shown;
    if (!NSEqualRects(buttons.frame, row.bounds)) buttons.frame = row.bounds;
    // The window buttons get their place in the row's own layout, which the buttons go by, so the row goes first.
    buttons.needsLayout = YES;
    [row layoutSubtreeIfNeeded];
}

void DPRelayoutNavigation(void) { DPRelayoutViews(DPNavLaidOut); }

void DPInstallNavigationLayout(void) {
    DPNavLaidOut = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaSidebarPaging, @selector(viewWillLayout), (IMP)DPPaging_viewWillLayout);
    DPHook(DPDiaSidebarHeader, @selector(layout), (IMP)DPHeader_layout);
}
