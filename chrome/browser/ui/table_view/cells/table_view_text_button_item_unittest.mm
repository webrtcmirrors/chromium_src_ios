// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/table_view/cells/table_view_text_button_item.h"

#include "base/mac/foundation_util.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_styler.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#import "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
using TableViewTextButtonItemTest = PlatformTest;
}

// Tests that the UILabels and delegate are set properly after a call to
// |configureCell:|.
TEST_F(TableViewTextButtonItemTest, SetProperties) {
  NSString* text = @"You need to do something.";
  NSString* buttonText = @"Tap to do something.";

  id<TextButtonItemDelegate> mock_delegate =
      [OCMockObject mockForProtocol:@protocol(TextButtonItemDelegate)];

  TableViewTextButtonItem* item =
      [[TableViewTextButtonItem alloc] initWithType:0];
  item.text = text;
  item.buttonText = buttonText;
  item.delegate = mock_delegate;

  id cell = [[[item cellClass] alloc] init];
  ASSERT_TRUE([cell isMemberOfClass:[TableViewTextButtonCell class]]);

  TableViewTextButtonCell* textButtonCell =
      base::mac::ObjCCastStrict<TableViewTextButtonCell>(cell);
  EXPECT_FALSE(textButtonCell.textLabel.text);
  EXPECT_FALSE(textButtonCell.button.titleLabel.text);
  EXPECT_FALSE(textButtonCell.delegate);

  [item configureCell:textButtonCell
           withStyler:[[ChromeTableViewStyler alloc] init]];
  EXPECT_NSEQ(text, textButtonCell.textLabel.text);
  EXPECT_NSEQ(buttonText, textButtonCell.button.titleLabel.text);
  EXPECT_TRUE(textButtonCell.delegate);
}

// Test that pressing the button invokes delegate.
TEST_F(TableViewTextButtonItemTest, DelegateCalled) {
  TableViewTextButtonItem* item =
      [[TableViewTextButtonItem alloc] initWithType:0];
  id cell = [[[item cellClass] alloc] init];
  ASSERT_TRUE([cell isMemberOfClass:[TableViewTextButtonCell class]]);

  TableViewTextButtonCell* textButtonCell =
      base::mac::ObjCCastStrict<TableViewTextButtonCell>(cell);
  id<TextButtonItemDelegate> mock_delegate =
      [OCMockObject mockForProtocol:@protocol(TextButtonItemDelegate)];
  [textButtonCell setDelegate:mock_delegate];

  OCMockObject* mock_delegate_obj = (OCMockObject*)mock_delegate;
  [[mock_delegate_obj expect] performButtonAction];
  UIButton* button = textButtonCell.button;
  [button sendActionsForControlEvents:UIControlEventTouchUpInside];
  EXPECT_OCMOCK_VERIFY(mock_delegate_obj);
}