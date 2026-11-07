#import "SidebarNavigation.h"

static BOOL DPShown;  // What the sidebars were last laid out for.

BOOL DPSidebarNavigationShown(void) { return DPSidebarNavigation.on && DPHideToolbar.on; }

static void DPInstallSidebarNavigation(void) {
    DPShown = DPSidebarNavigationShown();
    DPInstallNavigationMirror();
    DPInstallNavigationLayout();
    DPInstallNavigationMenus();
}

static void DPApplySidebarNavigation(DPPatch *patch) {
    DPShown = DPSidebarNavigationShown();
    DPRelayoutNavigation();
    DPScheduleNavigationRefresh();
}

// Hide Toolbar animates, so this follows it here rather than in an apply.
static void DPRelayoutSidebarNavigation(void) {
    if (DPShown != DPSidebarNavigationShown()) DPApplySidebarNavigation(&DPSidebarNavigation);
}

static NSRect DPInWindow(NSView *view) { return [view convertRect:view.bounds toView:nil]; }

// A sidebar that isn't open passes: with tabs at the top there's none.
static NSString *DPVerifySidebarNavigation(DPPatch *patch) {
    BOOL shown = DPSidebarNavigationShown();
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        if (header.hiddenOrHasHiddenAncestor) continue;
        NSView *sidebar = header.superview;
        NSView *lights = DPFindView(header, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTrafficLights); });
        NSView *buttons = DPFindView(header, ^BOOL(NSView *view) { return [view isKindOfClass:DPNavButtons.class]; });
        NSView *row = DPFindView(sidebar, ^BOOL(NSView *view) { return [view isKindOfClass:DPAddressRow.class]; });
        NSView *viewport = DPFindView(sidebar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSidebarViewport); });
        BOOL buttonsShow = buttons && !buttons.hiddenOrHasHiddenAncestor, rowShows = row && !row.hiddenOrHasHiddenAncestor;
        if (shown != buttonsShow) return shown ? @"no buttons in the sidebar" : @"buttons left in the sidebar";
        if (shown != rowShows) return shown ? @"no address in the sidebar" : @"address left in the sidebar";
        if (!viewport) return @"no tabs found in the sidebar";
        NSRect tabs = DPInWindow(viewport);
        if (!shown) continue;
        if (fabs(NSMaxY(tabs) - NSMinY(DPInWindow(row))) > 0.5) return @"tabs aren't right under the address";
        for (NSView *button in buttons.subviews) {
            if (button.hidden) continue;
            if (!NSContainsRect(DPInWindow(header), DPInWindow(button))) return @"a button sticks out of the header";
            if (lights && !lights.hidden && NSIntersectsRect(DPInWindow(lights), DPInWindow(button))) return @"a button covers the window buttons";
        }
    }
    return nil;
}

DP_PATCH(DPSidebarNavigation) {
    .key = @"sidebarNavigation",
    .order = 44,
    .title = @"Navigation in Sidebar",
    .detail = @"Put the sidebar, back, forward and reload buttons next to the window buttons, and the address under them, like Arc. "
              @"Click the address to change it.",
    .symbol = @"sidebar.squares.left sidebar.left",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .section = @"While It's Hidden",
    .classes = DPClasses(DPDiaSidebarPaging, DPDiaSidebarHeader, DPDiaSidebarViewport, DPDiaWebContents,
                         DPDiaReloadIcon, DPDiaAddressText),
    .install = DPInstallSidebarNavigation,
    .apply = DPApplySidebarNavigation,
    .relayout = DPRelayoutSidebarNavigation,
    .verify = DPVerifySidebarNavigation,
};
