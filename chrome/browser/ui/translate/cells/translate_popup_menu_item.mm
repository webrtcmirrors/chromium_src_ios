// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/translate/cells/translate_popup_menu_item.h"

#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_ui_constants.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_styler.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/ui_util/constraints_ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const CGFloat kCellHeight = 44;
const CGFloat kMargin = 15;
const CGFloat kMaxHeight = 100;
const CGFloat kVerticalMargin = 8;
const int kContentColorBlue = 0x1A73E8;
}  // namespace

@implementation TranslatePopupMenuItem

@synthesize actionIdentifier = _actionIdentifier;

- (instancetype)initWithType:(NSInteger)type {
  self = [super initWithType:type];
  if (self) {
    self.cellClass = [TranslatePopupMenuCell class];
  }
  return self;
}

- (void)configureCell:(TranslatePopupMenuCell*)cell
           withStyler:(ChromeTableViewStyler*)styler {
  [super configureCell:cell withStyler:styler];
  cell.accessibilityTraits = UIAccessibilityTraitButton;
  cell.accessoryType = self.accessoryType;
  [cell setTitle:self.title];
}

#pragma mark - PopupMenuItem

- (CGSize)cellSizeForWidth:(CGFloat)width {
  // TODO(crbug.com/828357): This should be done at the table view level.
  static TranslatePopupMenuCell* cell;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cell = [[TranslatePopupMenuCell alloc] init];
    [cell registerForContentSizeUpdates];
  });

  [self configureCell:cell withStyler:[[ChromeTableViewStyler alloc] init]];
  cell.frame = CGRectMake(0, 0, width, kMaxHeight);
  [cell setNeedsLayout];
  [cell layoutIfNeeded];
  return [cell systemLayoutSizeFittingSize:CGSizeMake(width, kMaxHeight)];
}

@end

#pragma mark - TranslatePopupMenuCell

@interface TranslatePopupMenuCell ()

@property(nonatomic, copy) UILabel* titleLabel;

@end

@implementation TranslatePopupMenuCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString*)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    UIView* selectedBackgroundView = [[UIView alloc] init];
    selectedBackgroundView.backgroundColor =
        [UIColor colorWithWhite:0 alpha:kSelectedItemBackgroundAlpha];
    self.selectedBackgroundView = selectedBackgroundView;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [self titleFont];
    _titleLabel.textColor = UIColorFromRGB(kContentColorBlue);
    _titleLabel.adjustsFontForContentSizeCategory = YES;

    [self.contentView addSubview:_titleLabel];

    ApplyVisualConstraintsWithMetrics(
        @[
          @"H:|-(margin)-[text]-(margin)-|",
          @"V:|-(verticalMargin)-[text]-(verticalMargin)-|"
        ],
        @{
          @"text" : _titleLabel,
        },
        @{
          @"margin" : @(kMargin),
          @"verticalMargin" : @(kVerticalMargin),
        });

    [self.contentView.heightAnchor
        constraintGreaterThanOrEqualToConstant:kCellHeight]
        .active = YES;

    self.isAccessibilityElement = YES;
  }
  return self;
}

- (void)setTitle:(NSString*)title {
  self.titleLabel.text = title;
}

- (void)registerForContentSizeUpdates {
  // This is needed because if the cell is static (used for height),
  // adjustsFontForContentSizeCategory isn't working.
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(preferredContentSizeDidChange:)
             name:UIContentSizeCategoryDidChangeNotification
           object:nil];
}

- (void)prepareForReuse {
  [super prepareForReuse];
  self.accessoryType = UITableViewCellAccessoryNone;
  [self setTitle:nil];
}

#pragma mark - Private

// Callback when the preferred Content Size change.
- (void)preferredContentSizeDidChange:(NSNotification*)notification {
  self.titleLabel.font = [self titleFont];
}

// Returns the font to be used for the title.
- (UIFont*)titleFont {
  return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

@end