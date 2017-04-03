// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_collection_updater.h"

#include "base/logging.h"
#include "base/mac/foundation_util.h"
#include "base/strings/sys_string_conversions.h"
#include "base/time/time.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/ui/collection_view/cells/collection_view_text_item.h"
#import "ios/chrome/browser/ui/collection_view/collection_view_controller.h"
#import "ios/chrome/browser/ui/collection_view/collection_view_model.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_article_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_button_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_expandable_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_favicon_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_footer_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_reading_list_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_stack_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_text_item.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestion.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_data_sink.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_data_source.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_image_fetcher.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller.h"
#import "ios/chrome/browser/ui/content_suggestions/identifier/content_suggestion_identifier.h"
#import "ios/chrome/browser/ui/content_suggestions/identifier/content_suggestions_section_information.h"
#include "ui/base/l10n/l10n_util.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

using CSCollectionViewItem =
    CollectionViewItem<ContentSuggestionIdentification>;
using CSCollectionViewModel = CollectionViewModel<CSCollectionViewItem*>;

// Enum defining the ItemType of this ContentSuggestionsCollectionUpdater.
typedef NS_ENUM(NSInteger, ItemType) {
  ItemTypeText = kItemTypeEnumZero,
  ItemTypeArticle,
  ItemTypeExpand,
  ItemTypeStack,
  ItemTypeFavicon,
  ItemTypeFooter,
  ItemTypeHeader,
  ItemTypeEmpty,
  ItemTypeReadingList,
};

typedef NS_ENUM(NSInteger, SectionIdentifier) {
  SectionIdentifierBookmarks = kSectionIdentifierEnumZero,
  SectionIdentifierArticles,
  SectionIdentifierReadingList,
  SectionIdentifierDefault,
};

// Update ContentSuggestionTypeForItemType if you update this function.
ItemType ItemTypeForContentSuggestionType(ContentSuggestionType type) {
  switch (type) {
    case ContentSuggestionTypeArticle:
      return ItemTypeArticle;
    case ContentSuggestionTypeEmpty:
      return ItemTypeEmpty;
    case ContentSuggestionTypeReadingList:
      return ItemTypeReadingList;
  }
}

ContentSuggestionType ContentSuggestionTypeForItemType(NSInteger type) {
  if (type == ItemTypeArticle)
    return ContentSuggestionTypeArticle;
  if (type == ItemTypeEmpty)
    return ContentSuggestionTypeEmpty;
  if (type == ItemTypeReadingList)
    return ContentSuggestionTypeReadingList;
  // Add new type here

  // Default type.
  return ContentSuggestionTypeEmpty;
}

// Returns the section identifier corresponding to the section |info|.
SectionIdentifier SectionIdentifierForInfo(
    ContentSuggestionsSectionInformation* info) {
  switch (info.sectionID) {
    case ContentSuggestionsSectionBookmarks:
      return SectionIdentifierBookmarks;

    case ContentSuggestionsSectionArticles:
      return SectionIdentifierArticles;

    case ContentSuggestionsSectionReadingList:
      return SectionIdentifierReadingList;

    case ContentSuggestionsSectionUnknown:
      return SectionIdentifierDefault;
  }
}

}  // namespace

@interface ContentSuggestionsCollectionUpdater ()<
    ContentSuggestionsArticleItemDelegate,
    ContentSuggestionsDataSink>

@property(nonatomic, weak) id<ContentSuggestionsDataSource> dataSource;
@property(nonatomic, strong)
    NSMutableDictionary<NSNumber*, ContentSuggestionsSectionInformation*>*
        sectionInfoBySectionIdentifier;

@end

@implementation ContentSuggestionsCollectionUpdater

@synthesize collectionViewController = _collectionViewController;
@synthesize dataSource = _dataSource;
@synthesize sectionInfoBySectionIdentifier = _sectionInfoBySectionIdentifier;

- (instancetype)initWithDataSource:
    (id<ContentSuggestionsDataSource>)dataSource {
  self = [super init];
  if (self) {
    _dataSource = dataSource;
    _dataSource.dataSink = self;
  }
  return self;
}

#pragma mark - Properties

- (void)setCollectionViewController:
    (ContentSuggestionsViewController*)collectionViewController {
  _collectionViewController = collectionViewController;

  [self reloadAllData];
}

#pragma mark - ContentSuggestionsDataSink

- (void)dataAvailableForSection:
    (ContentSuggestionsSectionInformation*)sectionInfo {
  SectionIdentifier sectionIdentifier = SectionIdentifierForInfo(sectionInfo);

  CSCollectionViewModel* model =
      self.collectionViewController.collectionViewModel;
  if ([model hasSectionForSectionIdentifier:sectionIdentifier]) {
    NSArray<CSCollectionViewItem*>* items =
        [model itemsInSectionWithIdentifier:sectionIdentifier];
    if (items.count > 0 && items[0].type != ItemTypeEmpty) {
      // Do not dismiss the presented items.
      return;
    }
  }

  [self.collectionViewController
      addSuggestions:[self.dataSource suggestionsForSection:sectionInfo]];
}

- (void)clearSuggestion:(ContentSuggestionIdentifier*)suggestionIdentifier {
  SectionIdentifier sectionIdentifier =
      SectionIdentifierForInfo(suggestionIdentifier.sectionInfo);
  if (![self.collectionViewController.collectionViewModel
          hasSectionForSectionIdentifier:sectionIdentifier]) {
    return;
  }

  NSArray<CSCollectionViewItem*>* itemsInSection =
      [self.collectionViewController.collectionViewModel
          itemsInSectionWithIdentifier:sectionIdentifier];

  CSCollectionViewItem* correspondingItem = nil;
  for (CSCollectionViewItem* item in itemsInSection) {
    if (item.suggestionIdentifier == suggestionIdentifier) {
      correspondingItem = item;
      break;
    }
  }

  if (!correspondingItem)
    return;

  NSIndexPath* indexPath = [self.collectionViewController.collectionViewModel
             indexPathForItem:correspondingItem
      inSectionWithIdentifier:sectionIdentifier];
  [self.collectionViewController dismissEntryAtIndexPath:indexPath];
}

- (void)reloadAllData {
  [self resetModels];

  // The data is reset, add the new data directly in the model then reload the
  // collection.
  NSArray<ContentSuggestion*>* suggestions = [self.dataSource allSuggestions];
  [self addSectionsForSuggestionsToModel:suggestions];
  [self addSuggestionsToModel:suggestions];
  [self.collectionViewController.collectionView reloadData];
}

- (void)clearSection:(ContentSuggestionsSectionInformation*)sectionInfo {
  SectionIdentifier sectionIdentifier = SectionIdentifierForInfo(sectionInfo);
  NSInteger section = [self.collectionViewController.collectionViewModel
      sectionIdentifierForSection:sectionIdentifier];

  [self.collectionViewController dismissSection:section];
}

#pragma mark - Public methods

- (BOOL)shouldUseCustomStyleForSection:(NSInteger)section {
  NSNumber* identifier = @([self.collectionViewController.collectionViewModel
      sectionIdentifierForSection:section]);
  ContentSuggestionsSectionInformation* sectionInformation =
      self.sectionInfoBySectionIdentifier[identifier];
  return sectionInformation.layout == ContentSuggestionsSectionLayoutCustom;
}

- (ContentSuggestionType)contentSuggestionTypeForItem:
    (CollectionViewItem*)item {
  return ContentSuggestionTypeForItemType(item.type);
}

- (NSArray<NSIndexPath*>*)addSuggestionsToModel:
    (NSArray<ContentSuggestion*>*)suggestions {
  if (suggestions.count == 0) {
    return [NSArray array];
  }

  NSMutableArray<NSIndexPath*>* indexPaths = [NSMutableArray array];
  for (ContentSuggestion* suggestion in suggestions) {
    ContentSuggestionsSectionInformation* sectionInfo =
        suggestion.suggestionIdentifier.sectionInfo;
    NSInteger sectionIdentifier = SectionIdentifierForInfo(sectionInfo);
    CSCollectionViewModel* model =
        self.collectionViewController.collectionViewModel;

    if (![model hasSectionForSectionIdentifier:sectionIdentifier])
      return [NSArray array];

    NSInteger section = [model sectionForSectionIdentifier:sectionIdentifier];
    NSIndexPath* indexPath = [NSIndexPath indexPathForItem:0 inSection:section];

    if (suggestion.type != ContentSuggestionTypeEmpty &&
        [model hasItemAtIndexPath:indexPath] &&
        [model itemAtIndexPath:indexPath].type == ItemTypeEmpty) {
      [self.collectionViewController dismissEntryAtIndexPath:indexPath];
    }

    switch (suggestion.type) {
      case ContentSuggestionTypeEmpty: {
        if ([model hasSectionForSectionIdentifier:sectionIdentifier] &&
            [model numberOfItemsInSection:[model sectionForSectionIdentifier:
                                                     sectionIdentifier]] == 0) {
          CSCollectionViewItem* item =
              [self emptyItemForSectionInfo:sectionInfo];
          NSIndexPath* addedIndexPath =
              [self addItem:item toSectionWithIdentifier:sectionIdentifier];
          [indexPaths addObject:addedIndexPath];
        }
        break;
      }
      case ContentSuggestionTypeArticle: {
        ContentSuggestionsArticleItem* articleItem =
            [[ContentSuggestionsArticleItem alloc]
                initWithType:ItemTypeForContentSuggestionType(suggestion.type)
                       title:suggestion.title
                    subtitle:suggestion.text
                    delegate:self
                         url:suggestion.url];

        articleItem.publisher = suggestion.publisher;
        articleItem.publishDate = suggestion.publishDate;

        articleItem.suggestionIdentifier = suggestion.suggestionIdentifier;

        NSIndexPath* addedIndexPath = [self addItem:articleItem
                            toSectionWithIdentifier:sectionIdentifier];
        [indexPaths addObject:addedIndexPath];
        break;
      }
      case ContentSuggestionTypeReadingList: {
        ContentSuggestionsReadingListItem* readingListItem =
            [[ContentSuggestionsReadingListItem alloc]
                     initWithType:ItemTypeReadingList
                              url:suggestion.url
                distillationState:ReadingListUIDistillationStatusPending];
        readingListItem.title = suggestion.title;
        readingListItem.subtitle = suggestion.publisher;

        readingListItem.suggestionIdentifier = suggestion.suggestionIdentifier;

        NSIndexPath* addedIndexPath = [self addItem:readingListItem
                            toSectionWithIdentifier:sectionIdentifier];
        [indexPaths addObject:addedIndexPath];
        break;
      }
    }
  }

  return indexPaths;
}

- (NSIndexSet*)addSectionsForSuggestionsToModel:
    (NSArray<ContentSuggestion*>*)suggestions {
  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];

  CSCollectionViewModel* model =
      self.collectionViewController.collectionViewModel;
  for (ContentSuggestion* suggestion in suggestions) {
    ContentSuggestionsSectionInformation* sectionInfo =
        suggestion.suggestionIdentifier.sectionInfo;
    NSInteger sectionIdentifier = SectionIdentifierForInfo(sectionInfo);

    if ([model hasSectionForSectionIdentifier:sectionIdentifier] ||
        (suggestion.type == ContentSuggestionTypeEmpty &&
         !sectionInfo.showIfEmpty)) {
      continue;
    }

    [model addSectionWithIdentifier:sectionIdentifier];
    self.sectionInfoBySectionIdentifier[@(sectionIdentifier)] = sectionInfo;
    [indexSet addIndex:[model sectionForSectionIdentifier:sectionIdentifier]];

    [self addHeader:sectionInfo];
    [self addFooterIfNeeded:sectionInfo];
  }
  return indexSet;
}

- (NSIndexPath*)addEmptyItemForSection:(NSInteger)section {
  CSCollectionViewModel* model =
      self.collectionViewController.collectionViewModel;
  NSInteger sectionIdentifier = [model sectionIdentifierForSection:section];
  ContentSuggestionsSectionInformation* sectionInfo =
      self.sectionInfoBySectionIdentifier[@(sectionIdentifier)];

  CSCollectionViewItem* item = [self emptyItemForSectionInfo:sectionInfo];
  return [self addItem:item toSectionWithIdentifier:sectionIdentifier];
}

#pragma mark - ContentSuggestionsArticleItemDelegate

- (void)loadImageForArticleItem:(ContentSuggestionsArticleItem*)articleItem {
  NSInteger sectionIdentifier =
      SectionIdentifierForInfo(articleItem.suggestionIdentifier.sectionInfo);

  __weak ContentSuggestionsCollectionUpdater* weakSelf = self;
  __weak ContentSuggestionsArticleItem* weakArticle = articleItem;

  void (^imageFetchedCallback)(UIImage*) = ^(UIImage* image) {
    ContentSuggestionsCollectionUpdater* strongSelf = weakSelf;
    ContentSuggestionsArticleItem* strongArticle = weakArticle;
    if (!strongSelf || !strongArticle) {
      return;
    }

    strongArticle.image = image;
    [strongSelf.collectionViewController
        reconfigureCellsForItems:@[ strongArticle ]
         inSectionWithIdentifier:sectionIdentifier];
  };

  [self.dataSource.imageFetcher
      fetchImageForSuggestion:articleItem.suggestionIdentifier
                     callback:imageFetchedCallback];
}

#pragma mark - Private methods

// Adds a footer to the section identified by |sectionInfo| if there is none
// present and the section info contains a title for it.
- (void)addFooterIfNeeded:(ContentSuggestionsSectionInformation*)sectionInfo {
  NSInteger sectionIdentifier = SectionIdentifierForInfo(sectionInfo);

  __weak ContentSuggestionsCollectionUpdater* weakSelf = self;
  if (sectionInfo.footerTitle &&
      ![self.collectionViewController.collectionViewModel
          footerForSectionWithIdentifier:sectionIdentifier]) {
    ContentSuggestionsFooterItem* footer = [[ContentSuggestionsFooterItem alloc]
        initWithType:ItemTypeFooter
               title:sectionInfo.footerTitle
               block:^{
                 [weakSelf runAdditionalActionForSection:sectionInfo];
               }];

    [self.collectionViewController.collectionViewModel
                       setFooter:footer
        forSectionWithIdentifier:sectionIdentifier];
  }
}

// Adds the header corresponding to |sectionInfo| to the section.
- (void)addHeader:(ContentSuggestionsSectionInformation*)sectionInfo {
  NSInteger sectionIdentifier = SectionIdentifierForInfo(sectionInfo);

  if (![self.collectionViewController.collectionViewModel
          headerForSectionWithIdentifier:sectionIdentifier]) {
    CollectionViewTextItem* header =
        [[CollectionViewTextItem alloc] initWithType:ItemTypeHeader];
    header.text = sectionInfo.title;
    [self.collectionViewController.collectionViewModel
                       setHeader:header
        forSectionWithIdentifier:sectionIdentifier];
  }
}

// Resets the models, removing the current CollectionViewItem and the
// SectionInfo.
- (void)resetModels {
  [self.collectionViewController loadModel];
  self.sectionInfoBySectionIdentifier = [[NSMutableDictionary alloc] init];
}

// Runs the additional action for the section identified by |sectionInfo|.
- (void)runAdditionalActionForSection:
    (ContentSuggestionsSectionInformation*)sectionInfo {
  SectionIdentifier sectionIdentifier = SectionIdentifierForInfo(sectionInfo);

  NSMutableArray<ContentSuggestionIdentifier*>* knownSuggestionIdentifiers =
      [NSMutableArray array];

  NSArray<CSCollectionViewItem*>* knownSuggestions =
      [self.collectionViewController.collectionViewModel
          itemsInSectionWithIdentifier:sectionIdentifier];
  for (CSCollectionViewItem* suggestion in knownSuggestions) {
    if (suggestion.type != ItemTypeEmpty) {
      [knownSuggestionIdentifiers addObject:suggestion.suggestionIdentifier];
    }
  }

  __weak ContentSuggestionsCollectionUpdater* weakSelf = self;
  [self.dataSource
      fetchMoreSuggestionsKnowing:knownSuggestionIdentifiers
                  fromSectionInfo:sectionInfo
                         callback:^(NSArray<ContentSuggestion*>* suggestions) {
                           [weakSelf moreSuggestionsFetched:suggestions];
                         }];
}

// Adds the |suggestions| to the collection view. All the suggestions must have
// the same sectionInfo.
- (void)moreSuggestionsFetched:(NSArray<ContentSuggestion*>*)suggestions {
  [self.collectionViewController addSuggestions:suggestions];
}

// Returns a item to be displayed when the section identified by |sectionInfo|
// is empty.
- (CSCollectionViewItem*)emptyItemForSectionInfo:
    (ContentSuggestionsSectionInformation*)sectionInfo {
  ContentSuggestionsTextItem* item =
      [[ContentSuggestionsTextItem alloc] initWithType:ItemTypeEmpty];
  item.text = l10n_util::GetNSString(IDS_NTP_TITLE_NO_SUGGESTIONS);
  item.detailText = sectionInfo.emptyText;

  return item;
}

// Adds |item| to |sectionIdentifier| section of the model of the
// CollectionView. Returns the IndexPath of the newly added item.
- (NSIndexPath*)addItem:(CSCollectionViewItem*)item
    toSectionWithIdentifier:(NSInteger)sectionIdentifier {
  CSCollectionViewModel* model =
      self.collectionViewController.collectionViewModel;
  NSInteger section = [model sectionForSectionIdentifier:sectionIdentifier];
  NSInteger itemNumber = [model numberOfItemsInSection:section];
  [model addItem:item toSectionWithIdentifier:sectionIdentifier];

  return [NSIndexPath indexPathForItem:itemNumber inSection:section];
}

@end
