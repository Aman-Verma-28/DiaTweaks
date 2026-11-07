#import "SidebarNavigation.h"

// The buttons and address stand in for the toolbar that Hide Toolbar keeps, out of sight, in each tab's pane. Clicks
// press its controls, so they do what Dia's do, and what they show is copied from it. Dia updates the toolbar a moment
// after the page's state changes, which ArcWebContents announces, so each change is followed by a look shortly after.

static NSHashTable<NSView *> *DPNavViews;
static NSTimer *DPLateRefresh;

NSView *DPNavPane(NSWindow *window) {
    NSResponder *responder = window.firstResponder;
    NSView *first = nil;
    for (NSView *pane in DPPanes) {
        if (pane.window != window || pane.hiddenOrHasHiddenAncestor) continue;
        if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:pane]) return pane;
        first = first ?: pane;
    }
    return first;
}

static NSView *DPToolbarView(NSView *pane, BOOL (^match)(NSView *view)) {
    NSView *bar = pane ? DPSubview(pane, DPDiaToolbar) : nil;
    return bar ? DPFindView(bar, match) : nil;
}

NSView *DPToolbarControl(NSView *pane, NSString *label) {
    return DPToolbarView(pane, ^BOOL(NSView *view) { return DPHasLabel(view, label); });
}

// The button's label says reload or stop, so it's found by the icon in it.
NSView *DPReloadControl(NSView *pane) {
    return DPToolbarView(pane, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaReloadIcon); }).superview;
}

BOOL DPPaneIsLoading(NSView *pane) {
    BOOL *loading = DPIvar(DPToolbarView(pane, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaReloadIcon); }), "isLoading");
    return loading && *loading;
}

// Dia's field says "host / page title"; like Arc's, this says the host.
NSString *DPAddressText(NSView *pane) {
    NSTextView *text = (NSTextView *)DPToolbarView(pane, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAddressText); });
    if (![text isKindOfClass:NSTextView.class]) return nil;
    return [text.string componentsSeparatedByString:@" / "].firstObject;
}

void DPTrackNavView(NSView *view) { [DPNavViews addObject:view]; }

static void DPRefreshNavigation(void) {
    NSMapTable<NSWindow *, NSView *> *panes = [NSMapTable weakToWeakObjectsMapTable];
    for (NSView *view in DPNavViews.allObjects) {
        NSWindow *window = view.window;
        if (!window || view.hiddenOrHasHiddenAncestor) continue;
        NSView *pane = [panes objectForKey:window] ?: DPNavPane(window);
        if (pane) [panes setObject:pane forKey:window];
        [(id)view mirrorPane:pane];
    }
}

void DPScheduleNavigationRefresh(void) {
    static BOOL soon;
    if (!DPSidebarNavigationShown()) return;
    if (!soon) {
        soon = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            soon = NO;
            DPRefreshNavigation();
        });
    }
    [DPLateRefresh invalidate];
    DPLateRefresh = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:NO block:^(NSTimer *timer) {
        DPLateRefresh = nil;
        DPRefreshNavigation();
    }];
}

static void DPContents_setUrl(id self, SEL _cmd, id url) {
    DPCallOriginal(DPContents_setUrl, self, url);
    DPScheduleNavigationRefresh();
}
static void DPContents_setIsLoading(id self, SEL _cmd, BOOL loading) {
    DPCallOriginal(DPContents_setIsLoading, self, loading);
    DPScheduleNavigationRefresh();
}
static void DPContents_setCanGoBack(id self, SEL _cmd, BOOL can) {
    DPCallOriginal(DPContents_setCanGoBack, self, can);
    DPScheduleNavigationRefresh();
}
static void DPContents_setCanGoForward(id self, SEL _cmd, BOOL can) {
    DPCallOriginal(DPContents_setCanGoForward, self, can);
    DPScheduleNavigationRefresh();
}
// Switching tabs or split panes.
static void DPContents_setHasFocus(id self, SEL _cmd, BOOL focus) {
    DPCallOriginal(DPContents_setHasFocus, self, focus);
    DPScheduleNavigationRefresh();
}
static void DPContents_setVisibility(id self, SEL _cmd, NSInteger visibility) {
    DPCallOriginal(DPContents_setVisibility, self, visibility);
    DPScheduleNavigationRefresh();
}

void DPInstallNavigationMirror(void) {
    DPNavViews = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaWebContents, @selector(setUrl:), (IMP)DPContents_setUrl);
    DPHook(DPDiaWebContents, @selector(setIsLoading:), (IMP)DPContents_setIsLoading);
    DPHook(DPDiaWebContents, @selector(setCanGoBack:), (IMP)DPContents_setCanGoBack);
    DPHook(DPDiaWebContents, @selector(setCanGoForward:), (IMP)DPContents_setCanGoForward);
    DPHook(DPDiaWebContents, @selector(setHasFocus:), (IMP)DPContents_setHasFocus);
    DPHook(DPDiaWebContents, @selector(setVisibility:), (IMP)DPContents_setVisibility);
}
