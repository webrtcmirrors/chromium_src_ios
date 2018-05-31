// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bookmarks/cells/bookmark_home_node_item.h"

#include "base/mac/foundation_util.h"
#include "base/strings/sys_string_conversions.h"
#include "components/bookmarks/browser/bookmark_node.h"
#import "ios/chrome/browser/experimental_flags.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_utils_ios.h"
#import "ios/chrome/browser/ui/bookmarks/cells/bookmark_folder_item.h"
#import "ios/chrome/browser/ui/bookmarks/cells/bookmark_table_cell.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_url_item.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation BookmarkHomeNodeItem
@synthesize bookmarkNode = _bookmarkNode;

- (instancetype)initWithType:(NSInteger)type
                bookmarkNode:(const bookmarks::BookmarkNode*)node {
  if ((self = [super initWithType:type])) {
    if (experimental_flags::IsBookmarksUIRebootEnabled()) {
      if (node->is_folder()) {
        self.cellClass = [TableViewBookmarkFolderCell class];
      } else {
        self.cellClass = [TableViewURLCell class];
      }
    } else {
      self.cellClass = [BookmarkTableCell class];
    }
    _bookmarkNode = node;
  }
  return self;
}

- (void)configureCell:(UITableViewCell*)cell
           withStyler:(ChromeTableViewStyler*)styler {
  [super configureCell:cell withStyler:styler];
  if (experimental_flags::IsBookmarksUIRebootEnabled()) {
    if (_bookmarkNode->is_folder()) {
      TableViewBookmarkFolderCell* bookmarkCell =
          base::mac::ObjCCastStrict<TableViewBookmarkFolderCell>(cell);
      bookmarkCell.folderTitleLabel.text =
          bookmark_utils_ios::TitleForBookmarkNode(_bookmarkNode);
      bookmarkCell.accessibilityIdentifier =
          bookmark_utils_ios::TitleForBookmarkNode(_bookmarkNode);
      bookmarkCell.folderImageView.image =
          [UIImage imageNamed:@"bookmark_blue_folder"];
      bookmarkCell.bookmarkAccessoryType =
          TableViewBookmarkFolderAccessoryTypeDisclosureIndicator;
    } else {
      TableViewURLCell* urlCell =
          base::mac::ObjCCastStrict<TableViewURLCell>(cell);
      urlCell.titleLabel.text =
          bookmark_utils_ios::TitleForBookmarkNode(_bookmarkNode);
      urlCell.URLLabel.text =
          base::SysUTF8ToNSString(_bookmarkNode->url().host());
    }
  } else {
    BookmarkTableCell* bookmarkCell =
        base::mac::ObjCCastStrict<BookmarkTableCell>(cell);
    [bookmarkCell setNode:self.bookmarkNode];
  }
}

@end
