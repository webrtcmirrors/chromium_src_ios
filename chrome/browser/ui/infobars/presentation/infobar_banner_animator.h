// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_INFOBARS_PRESENTATION_INFOBAR_BANNER_ANIMATOR_H_
#define IOS_CHROME_BROWSER_UI_INFOBARS_PRESENTATION_INFOBAR_BANNER_ANIMATOR_H_

#import <UIKit/UIKit.h>

// TODO(crbug.com/1372916): PLACEHOLDER Work in Progress class for the new
// InfobarUI.
@interface InfobarBannerAnimator
    : NSObject <UIViewControllerAnimatedTransitioning>

// YES if this animator is presenting a view controller, NO if it is dismissing
// one.
@property(nonatomic, assign) BOOL presenting;

@end

#endif  // IOS_CHROME_BROWSER_UI_INFOBARS_PRESENTATION_INFOBAR_BANNER_ANIMATOR_H_
