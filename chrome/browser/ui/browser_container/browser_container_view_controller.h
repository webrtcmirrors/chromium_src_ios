// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_BROWSER_CONTAINER_BROWSER_CONTAINER_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_BROWSER_CONTAINER_BROWSER_CONTAINER_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

// UIViewController which allows displaying and removing a content view.
@interface BrowserContainerViewController : UIViewController

// Adds the given |contentView| as a subview and removes the previously added
// |contentView| or |contentViewController|, if any. If |contentView| is nil
// then only old content view or view controller is removed.
@property(nonatomic, strong) UIView* contentView;

// Adds the given |contentViewController| as a subview and removes the
// previously added |contentView| or |contentViewController| if any.
// If |contentViewController| is nil then only old content view or view
// controller is removed.
@property(nonatomic, strong) UIViewController* contentViewController;

@end

#endif  // IOS_CHROME_BROWSER_UI_BROWSER_CONTAINER_BROWSER_CONTAINER_VIEW_CONTROLLER_H_
