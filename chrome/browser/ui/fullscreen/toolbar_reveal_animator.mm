// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/fullscreen/toolbar_reveal_animator.h"

#import "ios/chrome/common/material_timing.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation ToolbarRevealAnimator
@synthesize finalProgress = _finalProgress;

- (instancetype)initWithStartProgress:(CGFloat)startProgress {
  if (self = [super initWithStartProgress:startProgress
                                 duration:ios::material::kDuration1]) {
    // The toolbar should be shown when the fullscreen state is reset.
    _finalProgress = 1.0;
  }
  return self;
}

@end