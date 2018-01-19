// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_TOOLBAR_CLEAN_TOOLBAR_BUTTON_H_
#define IOS_CHROME_BROWSER_UI_TOOLBAR_CLEAN_TOOLBAR_BUTTON_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/toolbar/clean/toolbar_component_options.h"
#import "ios/chrome/browser/ui/util/named_guide.h"

// UIButton subclass used as a Toolbar component.
@interface ToolbarButton : UIButton

// Bitmask used for SizeClass visibility.
@property(nonatomic, assign) ToolbarComponentVisibility visibilityMask;
// Returns true if the ToolbarButton should be hidden in the current SizeClass.
@property(nonatomic, assign) BOOL hiddenInCurrentSizeClass;
// Returns true if the ToolbarButton should be hidden due to a current UI state
// or WebState.
@property(nonatomic, assign) BOOL hiddenInCurrentState;
// Named of the layout guide this button should be constrained to, if not nil.
@property(nonatomic, strong) GuideName* guideName;
// Priority of the constraints between the layout guide and the button, when
// activated. Use different priorities to avoid having conflicting constraints
// when moving the layout guide from one button to another.
@property(nonatomic, assign) UILayoutPriority constraintPriority;
// Returns a ToolbarButton using the three images parameters for their
// respective state.
+ (instancetype)toolbarButtonWithImageForNormalState:(UIImage*)normalImage
                            imageForHighlightedState:(UIImage*)highlightedImage
                               imageForDisabledState:(UIImage*)disabledImage;
// Checks if the ToolbarButton should be visible in the current SizeClass,
// afterwards it calls setHiddenForCurrentStateAndSizeClass if needed.
- (void)updateHiddenInCurrentSizeClass;

@end

#endif  // IOS_CHROME_BROWSER_UI_TOOLBAR_CLEAN_TOOLBAR_BUTTON_H_
