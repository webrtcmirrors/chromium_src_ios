// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/dialogs/java_script_dialog_blocking_state.h"

#include "base/logging.h"
#import "ios/web/public/navigation_item.h"
#import "ios/web/public/navigation_manager.h"
#import "ios/web/public/web_state/navigation_context.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

JavaScriptDialogBlockingState::JavaScriptDialogBlockingState(
    web::WebState* web_state)
    : web_state_(web_state) {
  web_state_->AddObserver(this);
}

JavaScriptDialogBlockingState::~JavaScriptDialogBlockingState() {
  // It is expected that WebStateDestroyed() will be received before this state
  // is deallocated.
  DCHECK(!web_state_);
}

void JavaScriptDialogBlockingState::JavaScriptDialogBlockingOptionSelected() {
  blocked_item_ = web_state_->GetNavigationManager()->GetLastCommittedItem();
  DCHECK(blocked_item_);
}

void JavaScriptDialogBlockingState::DidStartNavigation(
    web::WebState* web_state,
    web::NavigationContext* navigation_context) {
  DCHECK_EQ(web_state_, web_state);
  web::NavigationItem* item =
      web_state->GetNavigationManager()->GetLastCommittedItem();
  // The dialog blocking state should be reset for user-initiated loads or for
  // document-changing, non-reload navigations.
  bool navigation_is_reload = ui::PageTransitionCoreTypeIs(
      navigation_context->GetPageTransition(), ui::PAGE_TRANSITION_RELOAD);
  if (!navigation_context->IsRendererInitiated() ||
      (!navigation_context->IsSameDocument() && item != blocked_item_ &&
       !navigation_is_reload)) {
    dialog_count_ = 0;
    blocked_item_ = nullptr;
  }
}

void JavaScriptDialogBlockingState::WebStateDestroyed(
    web::WebState* web_state) {
  DCHECK_EQ(web_state_, web_state);
  web_state_->RemoveObserver(this);
  web_state_ = nullptr;
}

WEB_STATE_USER_DATA_KEY_IMPL(JavaScriptDialogBlockingState)
