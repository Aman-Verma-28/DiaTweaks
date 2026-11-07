// Shared by the parts of Navigation in Sidebar.
#import "StdPatch/StdPatch.h"
#import "Patches/HideToolbar/HideToolbar.h"

extern DPPatch DPSidebarNavigation;
BOOL DPSidebarNavigationShown(void);  // On, and the toolbar it stands in for is hidden.

// Buttons.m: the sidebar, back, forward and reload buttons, beside the window buttons.
@interface DPNavButtons : NSView
- (void)mirrorPane:(NSView *)pane;
@end
DPNavButtons *DPNavButtonsIn(NSView *row, BOOL create);

// Address.m: the address, under the buttons.
extern const CGFloat DPAddressRowHeight;
@interface DPAddressRow : NSView
- (void)mirrorPane:(NSView *)pane;
@end
DPAddressRow *DPAddressRowIn(NSView *holder, BOOL create);

// Mirror.m: each tab's hidden toolbar, which these press and copy.
NSView *DPNavPane(NSWindow *window);  // The pane with the focused page, which Dia's own menu items act on.
NSView *DPToolbarControl(NSView *pane, NSString *label);
NSView *DPReloadControl(NSView *pane);
BOOL DPPaneIsLoading(NSView *pane);
NSString *DPAddressText(NSView *pane);
void DPTrackNavView(NSView *view);
void DPScheduleNavigationRefresh(void);  // After Dia's toolbar catches up with the page.
void DPInstallNavigationMirror(void);

// Menus.m: Dia's menu items, and the site menu at the sidebar's button.
BOOL DPPerformMenuItem(NSString *title);
void DPOpenSiteMenu(NSView *anchor);
void DPInstallNavigationMenus(void);

// Layout.m
void DPInstallNavigationLayout(void);
void DPRelayoutNavigation(void);
