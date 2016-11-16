// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/navigation/navigation_manager_impl.h"

#include "base/logging.h"
#import "base/mac/scoped_nsobject.h"
#import "ios/web/navigation/crw_session_controller+private_constructors.h"
#import "ios/web/navigation/navigation_manager_delegate.h"
#include "ios/web/public/test/test_browser_state.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"

namespace web {
namespace {
// Stub class for NavigationManagerDelegate.
class TestNavigationManagerDelegate : public NavigationManagerDelegate {
  void GoToOffset(int offset) override {}
  void GoToIndex(int index) override {}
  void LoadURLWithParams(const NavigationManager::WebLoadParams&) override {}
  void OnNavigationItemsPruned(size_t pruned_item_count) override {}
  void OnNavigationItemChanged() override{};
  void OnNavigationItemCommitted(const LoadCommittedDetails&) override {}
  WebState* GetWebState() override { return nullptr; }
};
}  // namespace

// Test fixture for NavigationManagerImpl testing.
class NavigationManagerTest : public PlatformTest {
 protected:
  NavigationManagerTest()
      : manager_(new NavigationManagerImpl(&delegate_, &browser_state_)) {
    controller_.reset([[CRWSessionController alloc]
           initWithWindowName:nil
                     openerId:nil
                  openedByDOM:NO
        openerNavigationIndex:0
                 browserState:&browser_state_]);
    manager_->SetSessionController(controller_.get());
  }
  CRWSessionController* session_controller() { return controller_.get(); }
  NavigationManagerImpl* navigation_manager() { return manager_.get(); }

 private:
  TestBrowserState browser_state_;
  TestNavigationManagerDelegate delegate_;
  std::unique_ptr<NavigationManagerImpl> manager_;
  base::scoped_nsobject<CRWSessionController> controller_;
};

// Tests that GetPendingItemIndex() returns -1 if there is no pending entry.
TEST_F(NavigationManagerTest, GetPendingItemIndexWithoutPendingEntry) {
  [session_controller() addPendingEntry:GURL("http://www.url.com")
                               referrer:Referrer()
                             transition:ui::PAGE_TRANSITION_TYPED
                      rendererInitiated:NO];
  [session_controller() commitPendingEntry];
  EXPECT_EQ(-1, navigation_manager()->GetPendingItemIndex());
}

// Tests that GetPendingItemIndex() returns current item index if there is a
// pending entry.
TEST_F(NavigationManagerTest, GetPendingItemIndexWithPendingEntry) {
  [session_controller() addPendingEntry:GURL("http://www.url.com")
                               referrer:Referrer()
                             transition:ui::PAGE_TRANSITION_TYPED
                      rendererInitiated:NO];
  [session_controller() commitPendingEntry];
  [session_controller() addPendingEntry:GURL("http://www.url.com/0")
                               referrer:Referrer()
                             transition:ui::PAGE_TRANSITION_TYPED
                      rendererInitiated:NO];
  EXPECT_EQ(0, navigation_manager()->GetPendingItemIndex());
}

// Tests that GetPendingItemIndex() returns same index as was set by
// -[CRWSessionController setPendingEntryIndex:].
TEST_F(NavigationManagerTest, GetPendingItemIndexWithIndexedPendingEntry) {
  [session_controller() addPendingEntry:GURL("http://www.url.com")
                               referrer:Referrer()
                             transition:ui::PAGE_TRANSITION_TYPED
                      rendererInitiated:NO];
  [session_controller() commitPendingEntry];
  [session_controller() addPendingEntry:GURL("http://www.url.com/0")
                               referrer:Referrer()
                             transition:ui::PAGE_TRANSITION_TYPED
                      rendererInitiated:NO];
  [session_controller() commitPendingEntry];

  EXPECT_EQ(-1, navigation_manager()->GetPendingItemIndex());
  [session_controller() setPendingEntryIndex:0];
  EXPECT_EQ(0, navigation_manager()->GetPendingItemIndex());
}

}  // namespace web
