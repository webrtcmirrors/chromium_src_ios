// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web/blocked_popup_tab_helper.h"

#include "base/memory/ptr_util.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "components/infobars/core/infobar.h"
#include "components/infobars/core/infobar_manager.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/content_settings/host_content_settings_map_factory.h"
#include "ios/chrome/browser/infobars/infobar_manager_impl.h"
#import "ios/chrome/browser/web/chrome_web_test.h"
#import "ios/web/public/test/fakes/test_navigation_manager.h"
#import "ios/web/public/test/fakes/test_web_state.h"
#include "ios/web/web_state/blocked_popup_info.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "url/gurl.h"

// Test fixture for BlockedPopupTabHelper class.
class BlockedPopupTabHelperTest : public ChromeWebTest {
 protected:
  BlockedPopupTabHelperTest() {
    web_state_.SetBrowserState(GetBrowserState());
    web_state_.SetNavigationManager(
        base::MakeUnique<web::TestNavigationManager>());

    BlockedPopupTabHelper::CreateForWebState(&web_state_);
    InfoBarManagerImpl::CreateForWebState(&web_state_);
  }

  // Returns true if InfoBarManager is being observed.
  bool IsObservingSources() {
    return GetBlockedPopupTabHelper()->scoped_observer_.IsObservingSources();
  }

  // Returns BlockedPopupTabHelper that is being tested.
  BlockedPopupTabHelper* GetBlockedPopupTabHelper() {
    return BlockedPopupTabHelper::FromWebState(&web_state_);
  }

  web::TestWebState web_state_;
};

// Tests ShouldBlockPopup method. This test changes content settings without
// restoring them back, which is fine because changes do not persist across test
// runs.
TEST_F(BlockedPopupTabHelperTest, ShouldBlockPopup) {
  const GURL source_url1("https://source-url1");
  EXPECT_TRUE(GetBlockedPopupTabHelper()->ShouldBlockPopup(source_url1));

  // Allow popups for |source_url1|.
  scoped_refptr<HostContentSettingsMap> settings_map(
      ios::HostContentSettingsMapFactory::GetForBrowserState(
          chrome_browser_state_.get()));
  settings_map->SetContentSettingCustomScope(
      ContentSettingsPattern::FromURL(source_url1),
      ContentSettingsPattern::Wildcard(), CONTENT_SETTINGS_TYPE_POPUPS,
      std::string(), CONTENT_SETTING_ALLOW);

  EXPECT_FALSE(GetBlockedPopupTabHelper()->ShouldBlockPopup(source_url1));
  const GURL source_url2("https://source-url2");
  EXPECT_TRUE(GetBlockedPopupTabHelper()->ShouldBlockPopup(source_url2));

  // Allow all popups.
  settings_map->SetDefaultContentSetting(CONTENT_SETTINGS_TYPE_POPUPS,
                                         CONTENT_SETTING_ALLOW);

  EXPECT_FALSE(GetBlockedPopupTabHelper()->ShouldBlockPopup(source_url1));
  EXPECT_FALSE(GetBlockedPopupTabHelper()->ShouldBlockPopup(source_url2));
}

// Tests that an infobar is added to the infobar manager when
// BlockedPopupTabHelper::HandlePopup() is called.
TEST_F(BlockedPopupTabHelperTest, ShowAndDismissInfoBar) {
  const GURL test_url("https://popups.example.com");
  web::BlockedPopupInfo popup_info(test_url, web::Referrer(), nil, nil);

  // Check that there are no infobars showing and no registered observers.
  infobars::InfoBarManager* infobar_manager =
      InfoBarManagerImpl::FromWebState(&web_state_);
  EXPECT_EQ(0U, infobar_manager->infobar_count());
  EXPECT_FALSE(IsObservingSources());

  // Call |HandlePopup| to show an infobar.
  GetBlockedPopupTabHelper()->HandlePopup(popup_info);
  ASSERT_EQ(1U, infobar_manager->infobar_count());
  EXPECT_TRUE(IsObservingSources());

  // Dismiss the infobar and check that the tab helper no longer has any
  // registered observers.
  infobar_manager->infobar_at(0)->RemoveSelf();
  EXPECT_EQ(0U, infobar_manager->infobar_count());
  EXPECT_FALSE(IsObservingSources());
}
