#import "SidebarNavigation.h"

static NSView *DPMenuAnchor;  // While the sidebar's site button presses Dia's, the menu Dia opens at its own opens here.

static NSMenuItem *DPMenuItemTitled(NSMenu *menu, NSString *title) {
    for (NSMenuItem *item in menu.itemArray) {
        NSMenuItem *found = [item.title isEqual:title] ? item : DPMenuItemTitled(item.submenu, title);
        if (found) return found;
    }
    return nil;
}

// Through the menu, so whatever watches Dia's menu items, such as the Copied message options, sees it too.
BOOL DPPerformMenuItem(NSString *title) {
    NSMenuItem *item = DPMenuItemTitled(NSApp.mainMenu, title);
    if (!item) return NO;
    [item.menu update];
    if (!item.enabled) return NO;
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
    return YES;
}

static BOOL DPMenu_popUp(NSMenu *self, SEL _cmd, NSMenuItem *item, NSPoint location, NSView *view) {
    NSView *anchor = DPMenuAnchor;
    DPMenuAnchor = nil;
    if (anchor) return DPCallOriginal(DPMenu_popUp, self, nil, NSMakePoint(0, anchor.isFlipped ? NSHeight(anchor.bounds) + 4 : -4), anchor);
    return DPCallOriginal(DPMenu_popUp, self, item, location, view);
}

// Dia opens the site menu at once, at its own button, which is out of sight.
void DPOpenSiteMenu(NSView *anchor) {
    DPMenuAnchor = anchor;
    [DPToolbarControl(DPNavPane(anchor.window), @"Site menu") accessibilityPerformPress];
    DPMenuAnchor = nil;
}

void DPInstallNavigationMenus(void) {
    DPHook("NSMenu", @selector(popUpMenuPositioningItem:atLocation:inView:), (IMP)DPMenu_popUp);
}
