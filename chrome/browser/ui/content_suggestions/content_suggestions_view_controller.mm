// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller.h"

#include "base/mac/foundation_util.h"
#import "ios/chrome/browser/ui/collection_view/cells/MDCCollectionViewCell+Chrome.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_item.h"
#import "ios/chrome/browser/ui/collection_view/collection_view_model.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_article_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_button_item_actions.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_stack_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_stack_item_actions.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/expandable_item.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestion.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_collection_updater.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_commands.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const NSTimeInterval kAnimationDuration = 0.35;
}  // namespace

@interface ContentSuggestionsViewController ()<SuggestionsStackItemActions>

@property(nonatomic, strong)
    ContentSuggestionsCollectionUpdater* collectionUpdater;

// Expand or collapse the |cell|, if it is a ContentSuggestionsExpandableCell,
// according to |expand|.
- (void)expand:(BOOL)expand cell:(UICollectionViewCell*)cell;

@end

@implementation ContentSuggestionsViewController

@synthesize suggestionCommandHandler = _suggestionCommandHandler;
@synthesize collectionUpdater = _collectionUpdater;
@dynamic collectionViewModel;

#pragma mark - Public

- (instancetype)initWithStyle:(CollectionViewControllerStyle)style
                   dataSource:(id<ContentSuggestionsDataSource>)dataSource {
  self = [super initWithStyle:style];
  if (self) {
    _collectionUpdater = [[ContentSuggestionsCollectionUpdater alloc]
        initWithDataSource:dataSource];
  }
  return self;
}

- (void)dismissEntryAtIndexPath:(NSIndexPath*)indexPath {
  if (!indexPath || ![self.collectionViewModel hasItemAtIndexPath:indexPath]) {
    return;
  }

  [self.collectionView performBatchUpdates:^{
    [self collectionView:self.collectionView
        willDeleteItemsAtIndexPaths:@[ indexPath ]];

    [self.collectionView deleteItemsAtIndexPaths:@[ indexPath ]];

    // Check if the section is now empty.
    [self addEmptySectionPlaceholderIfNeeded:indexPath.section];
  }
      completion:^(BOOL) {
        // The context menu could be displayed for the deleted entry.
        [self.suggestionCommandHandler dismissContextMenu];
      }];
}

- (void)dismissSection:(NSInteger)section {
  if (section >= [self numberOfSectionsInCollectionView:self.collectionView]) {
    return;
  }

  NSInteger sectionIdentifier =
      [self.collectionViewModel sectionIdentifierForSection:section];

  [self.collectionView performBatchUpdates:^{
    [self.collectionViewModel removeSectionWithIdentifier:sectionIdentifier];
    [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:section]];
  }
      completion:^(BOOL) {
        // The context menu could be displayed for the deleted entries.
        [self.suggestionCommandHandler dismissContextMenu];
      }];
}

- (void)addSuggestions:(NSArray<ContentSuggestion*>*)suggestions {
  if (suggestions.count == 0) {
    return;
  }

  [self.collectionView performBatchUpdates:^{
    NSIndexSet* addedSections =
        [self.collectionUpdater addSectionsForSuggestionsToModel:suggestions];
    [self.collectionView insertSections:addedSections];
  }
                                completion:nil];

  [self.collectionView performBatchUpdates:^{
    NSArray<NSIndexPath*>* addedItems =
        [self.collectionUpdater addSuggestionsToModel:suggestions];
    [self.collectionView insertItemsAtIndexPaths:addedItems];
  }
                                completion:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  _collectionUpdater.collectionViewController = self;

  self.collectionView.delegate = self;
  self.styler.cellStyle = MDCCollectionViewCellStyleCard;

  UILongPressGestureRecognizer* longPressRecognizer =
      [[UILongPressGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(handleLongPress:)];
  longPressRecognizer.numberOfTouchesRequired = 1;
  [self.collectionView addGestureRecognizer:longPressRecognizer];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView*)collectionView
    didSelectItemAtIndexPath:(NSIndexPath*)indexPath {
  [super collectionView:collectionView didSelectItemAtIndexPath:indexPath];

  CollectionViewItem* item =
      [self.collectionViewModel itemAtIndexPath:indexPath];
  switch ([self.collectionUpdater contentSuggestionTypeForItem:item]) {
    case ContentSuggestionTypeArticle:
      [self openArticle:item];
      break;
    case ContentSuggestionTypeEmpty:
      break;
  }
}

#pragma mark - ContentSuggestionsExpandableCellDelegate

- (void)collapseCell:(UICollectionViewCell*)cell {
  [self expand:NO cell:cell];
}

- (void)expandCell:(UICollectionViewCell*)cell {
  [self expand:YES cell:cell];
}

#pragma mark - ContentSuggestionsFaviconCellDelegate

- (void)openFaviconAtIndexPath:(NSIndexPath*)innerIndexPath {
  [self.suggestionCommandHandler openFaviconAtIndex:innerIndexPath.item];
}

#pragma mark - SuggestionsStackItemActions

- (void)openReadingListFirstItem:(id)sender {
  [self.suggestionCommandHandler openFirstPageOfReadingList];
}

#pragma mark - MDCCollectionViewStylingDelegate

- (UIColor*)collectionView:(nonnull UICollectionView*)collectionView
    cellBackgroundColorAtIndexPath:(nonnull NSIndexPath*)indexPath {
  if ([self.collectionUpdater
          shouldUseCustomStyleForSection:indexPath.section]) {
    return [UIColor clearColor];
  }
  return [UIColor whiteColor];
}

- (BOOL)collectionView:(nonnull UICollectionView*)collectionView
    shouldHideItemBackgroundAtIndexPath:(nonnull NSIndexPath*)indexPath {
  if ([self.collectionUpdater
          shouldUseCustomStyleForSection:indexPath.section]) {
    return YES;
  }
  return NO;
}

- (BOOL)collectionView:(UICollectionView*)collectionView
    shouldHideHeaderBackgroundForSection:(NSInteger)section {
  return YES;
}

- (CGFloat)collectionView:(UICollectionView*)collectionView
    cellHeightAtIndexPath:(NSIndexPath*)indexPath {
  CollectionViewItem* item =
      [self.collectionViewModel itemAtIndexPath:indexPath];
  UIEdgeInsets inset = [self collectionView:collectionView
                                     layout:collectionView.collectionViewLayout
                     insetForSectionAtIndex:indexPath.section];

  return [MDCCollectionViewCell
      cr_preferredHeightForWidth:CGRectGetWidth(collectionView.bounds) -
                                 inset.left - inset.right
                         forItem:item];
}

#pragma mark - Private

- (void)expand:(BOOL)expand cell:(UICollectionViewCell*)cell {
  NSIndexPath* indexPath = [self.collectionView indexPathForCell:cell];
  CollectionViewItem* item =
      [self.collectionViewModel itemAtIndexPath:indexPath];
  if ([item conformsToProtocol:@protocol(ExpandableItem)]) {
    id<ExpandableItem> expandableItem = (id<ExpandableItem>)item;

    NSInteger sectionIdentifier = [self.collectionViewModel
        sectionIdentifierForSection:indexPath.section];

    expandableItem.expanded = expand;
    [self reconfigureCellsForItems:@[ item ]
           inSectionWithIdentifier:sectionIdentifier];

    [UIView
        animateWithDuration:kAnimationDuration
                 animations:^{
                   [self.collectionView.collectionViewLayout invalidateLayout];
                 }];
  }
}

- (void)openArticle:(CollectionViewItem*)item {
  ContentSuggestionsArticleItem* article =
      base::mac::ObjCCastStrict<ContentSuggestionsArticleItem>(item);
  [self.suggestionCommandHandler openURL:article.articleURL];
}

- (void)handleLongPress:(UILongPressGestureRecognizer*)gestureRecognizer {
  if (self.editor.editing ||
      gestureRecognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }

  CGPoint touchLocation =
      [gestureRecognizer locationOfTouch:0 inView:self.collectionView];
  NSIndexPath* touchedItemIndexPath =
      [self.collectionView indexPathForItemAtPoint:touchLocation];
  if (!touchedItemIndexPath ||
      ![self.collectionViewModel hasItemAtIndexPath:touchedItemIndexPath]) {
    // Make sure there is an item at this position.
    return;
  }
  CollectionViewItem* touchedItem =
      [self.collectionViewModel itemAtIndexPath:touchedItemIndexPath];

  if ([self.collectionUpdater contentSuggestionTypeForItem:touchedItem] !=
      ContentSuggestionTypeArticle) {
    // Only trigger context menu on articles.
    return;
  }

  ContentSuggestionsArticleItem* articleItem =
      base::mac::ObjCCastStrict<ContentSuggestionsArticleItem>(touchedItem);

  [self.suggestionCommandHandler
      displayContextMenuForArticle:articleItem
                           atPoint:touchLocation
                       atIndexPath:touchedItemIndexPath];
}

// Checks if the |section| is empty and add an empty element if it is the case.
// Must be called from inside a performBatchUpdates: block.
- (void)addEmptySectionPlaceholderIfNeeded:(NSInteger)section {
  if ([self.collectionViewModel numberOfItemsInSection:section] > 0)
    return;

  NSIndexPath* emptyItem =
      [self.collectionUpdater addEmptyItemForSection:section];
  [self.collectionView insertItemsAtIndexPaths:@[ emptyItem ]];
}

@end
