// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_TAB_GRID_TAB_GRID_BOTTOM_TOOLBAR_H_
#define IOS_CHROME_BROWSER_UI_TAB_GRID_TAB_GRID_BOTTOM_TOOLBAR_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/tab_grid/tab_grid_paging.h"

@class TabGridNewTabButton;

// Bottom toolbar for TabGrid. The appearance of the toolbar is decided by
// screen size and current TabGrid page:
//
// Horizontal-compact and vertical-regular screen size:
//   Small newTabButton, translucent background.
//   Incognito & Regular page: [leadingButton, newTabButton, trailingButton]
//   Remote page:              [                             trailingButton]
//
// Other screen size:
//   Large newTabButton, transparent background.
//   Incognito & Regular page: [                               newTabButton]
//   Remote page:              [                                           ]
@interface TabGridBottomToolbar : UIToolbar
// This property together with self.traitCollection control the items shown
// in toolbar and its background color. Setting this property will also set it
// on |newTabButton|.
@property(nonatomic, assign) TabGridPage page;
// These components are publicly available to allow the user to set their
// contents, visibility and actions.
@property(nonatomic, strong, readonly) UIBarButtonItem* leadingButton;
@property(nonatomic, strong, readonly) UIBarButtonItem* trailingButton;
// Clang does not allow property getters to start with the reserved word "new",
// but provides a workaround. The getter must be set before the property is
// declared.
- (TabGridNewTabButton*)newTabButton __attribute__((objc_method_family(none)));
@property(nonatomic, strong, readonly) TabGridNewTabButton* newTabButton;

// Hides components and uses a black background color for tab grid transition
// animation.
- (void)hide;
// Recovers the normal appearance for tab grid transition animation.
- (void)show;
@end

#endif  // IOS_CHROME_BROWSER_UI_TAB_GRID_TAB_GRID_BOTTOM_TOOLBAR_H_
