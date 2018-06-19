// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/list_model/list_model.h"

#include "base/logging.h"
#import "base/numerics/safe_conversions.h"
#import "ios/chrome/browser/ui/list_model/list_item.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

NSString* const kListModelCollapsedKey = @"ChromeListModelCollapsedSections";

namespace {

typedef NSMutableArray<ListItem*> SectionItems;
}

@implementation ListModel {
  // Ordered list of section identifiers, one per section in the model.
  NSMutableArray<NSNumber*>* _sectionIdentifiers;

  // The lists of section items, one per section.
  NSMutableArray<SectionItems*>* _sections;

  // Maps from section identifier to header and footer.
  NSMutableDictionary<NSNumber*, ListItem*>* _headers;
  NSMutableDictionary<NSNumber*, ListItem*>* _footers;

  // Maps from collapsed keys to section identifier.
  NSMutableDictionary<NSNumber*, NSString*>* _collapsedKeys;
}

- (instancetype)init {
  if ((self = [super init])) {
    _sectionIdentifiers = [[NSMutableArray alloc] init];
    _sections = [[NSMutableArray alloc] init];
    _headers = [[NSMutableDictionary alloc] init];
    _footers = [[NSMutableDictionary alloc] init];
  }
  return self;
}

#pragma mark Modification methods

- (void)addSectionWithIdentifier:(NSInteger)sectionIdentifier {
  DCHECK_GE(sectionIdentifier, kSectionIdentifierEnumZero);
  DCHECK_EQ(base::checked_cast<NSUInteger>(NSNotFound),
            [self internalSectionForIdentifier:sectionIdentifier]);
  [_sectionIdentifiers addObject:@(sectionIdentifier)];

  SectionItems* section = [[SectionItems alloc] init];
  [_sections addObject:section];
}

- (void)insertSectionWithIdentifier:(NSInteger)sectionIdentifier
                            atIndex:(NSUInteger)index {
  DCHECK_GE(sectionIdentifier, kSectionIdentifierEnumZero);
  DCHECK_EQ(base::checked_cast<NSUInteger>(NSNotFound),
            [self internalSectionForIdentifier:sectionIdentifier]);
  DCHECK_LE(index, [_sections count]);

  [_sectionIdentifiers insertObject:@(sectionIdentifier) atIndex:index];

  SectionItems* section = [[SectionItems alloc] init];
  [_sections insertObject:section atIndex:index];
}

- (void)addItem:(ListItem*)item
    toSectionWithIdentifier:(NSInteger)sectionIdentifier {
  DCHECK_GE(item.type, kItemTypeEnumZero);
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  SectionItems* items = [_sections objectAtIndex:section];
  [items addObject:item];
}

- (void)insertItem:(ListItem*)item
    inSectionWithIdentifier:(NSInteger)sectionIdentifier
                    atIndex:(NSUInteger)index {
  DCHECK_GE(item.type, kItemTypeEnumZero);
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  SectionItems* items = [_sections objectAtIndex:section];
  DCHECK(index <= [items count]);
  [items insertObject:item atIndex:index];
}

- (void)removeItemWithType:(NSInteger)itemType
    fromSectionWithIdentifier:(NSInteger)sectionIdentifier {
  [self removeItemWithType:itemType
      fromSectionWithIdentifier:sectionIdentifier
                        atIndex:0];
}

- (void)removeItemWithType:(NSInteger)itemType
    fromSectionWithIdentifier:(NSInteger)sectionIdentifier
                      atIndex:(NSUInteger)index {
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  SectionItems* items = [_sections objectAtIndex:section];
  NSInteger item =
      [self itemForItemType:itemType inSectionItems:items atIndex:index];
  DCHECK_NE(NSNotFound, item);
  [items removeObjectAtIndex:item];
}

- (void)removeSectionWithIdentifier:(NSInteger)sectionIdentifier {
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  [_sectionIdentifiers removeObjectAtIndex:section];
  [_sections removeObjectAtIndex:section];
  [_collapsedKeys removeObjectForKey:@(sectionIdentifier)];
}

- (void)setHeader:(ListItem*)header
    forSectionWithIdentifier:(NSInteger)sectionIdentifier {
  NSNumber* key = [NSNumber numberWithInteger:sectionIdentifier];
  if (header) {
    [_headers setObject:header forKey:key];
  } else {
    [_headers removeObjectForKey:key];
  }
}

- (void)setFooter:(ListItem*)footer
    forSectionWithIdentifier:(NSInteger)sectionIdentifier {
  NSNumber* key = [NSNumber numberWithInteger:sectionIdentifier];
  if (footer) {
    [_footers setObject:footer forKey:key];
  } else {
    [_footers removeObjectForKey:key];
  }
}

#pragma mark Query model coordinates from index paths

- (NSInteger)sectionIdentifierForSection:(NSInteger)section {
  DCHECK_LT(base::checked_cast<NSUInteger>(section),
            [_sectionIdentifiers count]);
  return [[_sectionIdentifiers objectAtIndex:section] integerValue];
}

- (NSInteger)itemTypeForIndexPath:(NSIndexPath*)indexPath {
  return [self itemAtIndexPath:indexPath].type;
}

- (NSUInteger)indexInItemTypeForIndexPath:(NSIndexPath*)indexPath {
  DCHECK_LT(base::checked_cast<NSUInteger>(indexPath.section),
            [_sections count]);
  SectionItems* items = [_sections objectAtIndex:indexPath.section];

  ListItem* item = [self itemAtIndexPath:indexPath];
  NSUInteger indexInItemType =
      [self indexInItemTypeForItem:item inSectionItems:items];
  return indexInItemType;
}

#pragma mark Query items from index paths

- (BOOL)hasItemAtIndexPath:(NSIndexPath*)indexPath {
  if (!indexPath)
    return NO;

  if (base::checked_cast<NSUInteger>(indexPath.section) < [_sections count]) {
    SectionItems* items = [_sections objectAtIndex:indexPath.section];
    return base::checked_cast<NSUInteger>(indexPath.item) < [items count];
  }
  return NO;
}

- (ListItem*)itemAtIndexPath:(NSIndexPath*)indexPath {
  DCHECK(indexPath);
  DCHECK_LT(base::checked_cast<NSUInteger>(indexPath.section),
            [_sections count]);
  SectionItems* items = [_sections objectAtIndex:indexPath.section];

  DCHECK_LT(base::checked_cast<NSUInteger>(indexPath.item), [items count]);
  return [items objectAtIndex:indexPath.item];
}

- (ListItem*)headerForSection:(NSInteger)section {
  NSInteger sectionIdentifier = [self sectionIdentifierForSection:section];
  NSNumber* key = [NSNumber numberWithInteger:sectionIdentifier];
  return [_headers objectForKey:key];
}

- (ListItem*)footerForSection:(NSInteger)section {
  NSInteger sectionIdentifier = [self sectionIdentifierForSection:section];
  NSNumber* key = [NSNumber numberWithInteger:sectionIdentifier];
  return [_footers objectForKey:key];
}

- (NSArray<ListItem*>*)itemsInSectionWithIdentifier:
    (NSInteger)sectionIdentifier {
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  DCHECK_LT(base::checked_cast<NSUInteger>(section), [_sections count]);
  return [_sections objectAtIndex:section];
}

- (ListItem*)headerForSectionWithIdentifier:(NSInteger)sectionIdentifier {
  NSNumber* key = [NSNumber numberWithInteger:sectionIdentifier];
  return [_headers objectForKey:key];
}

- (ListItem*)footerForSectionWithIdentifier:(NSInteger)sectionIdentifier {
  NSNumber* key = [NSNumber numberWithInteger:sectionIdentifier];
  return [_footers objectForKey:key];
}

#pragma mark Query index paths from model coordinates

- (BOOL)hasSectionForSectionIdentifier:(NSInteger)sectionIdentifier {
  NSUInteger section = [self internalSectionForIdentifier:sectionIdentifier];
  return section != base::checked_cast<NSUInteger>(NSNotFound);
}

- (NSInteger)sectionForSectionIdentifier:(NSInteger)sectionIdentifier {
  NSUInteger section = [self internalSectionForIdentifier:sectionIdentifier];
  DCHECK_NE(base::checked_cast<NSUInteger>(NSNotFound), section);
  return section;
}

- (BOOL)hasItemForItemType:(NSInteger)itemType
         sectionIdentifier:(NSInteger)sectionIdentifier {
  return [self hasItemForItemType:itemType
                sectionIdentifier:sectionIdentifier
                          atIndex:0];
}

- (NSIndexPath*)indexPathForItemType:(NSInteger)itemType
                   sectionIdentifier:(NSInteger)sectionIdentifier {
  return [self indexPathForItemType:itemType
                  sectionIdentifier:sectionIdentifier
                            atIndex:0];
}

- (BOOL)hasItemForItemType:(NSInteger)itemType
         sectionIdentifier:(NSInteger)sectionIdentifier
                   atIndex:(NSUInteger)index {
  if (![self hasSectionForSectionIdentifier:sectionIdentifier]) {
    return NO;
  }
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  SectionItems* items = [_sections objectAtIndex:section];
  NSInteger item =
      [self itemForItemType:itemType inSectionItems:items atIndex:index];
  return item != NSNotFound;
}

- (NSIndexPath*)indexPathForItemType:(NSInteger)itemType
                   sectionIdentifier:(NSInteger)sectionIdentifier
                             atIndex:(NSUInteger)index {
  NSInteger section = [self sectionForSectionIdentifier:sectionIdentifier];
  SectionItems* items = [_sections objectAtIndex:section];
  NSInteger item =
      [self itemForItemType:itemType inSectionItems:items atIndex:index];
  return [NSIndexPath indexPathForItem:item inSection:section];
}

#pragma mark Query index paths from items

- (BOOL)hasItem:(ListItem*)item
    inSectionWithIdentifier:(NSInteger)sectionIdentifier {
  return [[self itemsInSectionWithIdentifier:sectionIdentifier]
             indexOfObject:item] != NSNotFound;
}

- (BOOL)hasItem:(ListItem*)item {
  for (NSNumber* section in _sectionIdentifiers) {
    if ([self hasItem:item inSectionWithIdentifier:[section integerValue]])
      return YES;
  }
  return NO;
}

- (NSIndexPath*)indexPathForItem:(ListItem*)item {
  for (NSUInteger section = 0; section < _sections.count; section++) {
    NSInteger itemIndex = [_sections[section] indexOfObject:item];
    if (itemIndex != NSNotFound) {
      return [NSIndexPath indexPathForItem:itemIndex inSection:section];
    }
  }
  NOTREACHED();
  return nil;
}

#pragma mark Data sourcing

- (NSInteger)numberOfSections {
  return [_sections count];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
  DCHECK_LT(base::checked_cast<NSUInteger>(section), [_sections count]);
  NSInteger sectionIdentifier = [self sectionIdentifierForSection:section];
  if ([self sectionIsCollapsed:sectionIdentifier])
    return 0;
  SectionItems* items = [_sections objectAtIndex:section];
  return items.count;
}

#pragma mark Collapsing methods.

- (void)setSectionIdentifier:(NSInteger)sectionIdentifier
                collapsedKey:(NSString*)collapsedKey {
  // Check that the sectionIdentifier exists.
  DCHECK([self hasSectionForSectionIdentifier:sectionIdentifier]);
  // Check that the collapsedKey is not being used already.
  DCHECK(![self.collapsedKeys allKeysForObject:collapsedKey].count);
  [self.collapsedKeys setObject:collapsedKey forKey:@(sectionIdentifier)];
}

- (void)setSection:(NSInteger)sectionIdentifier collapsed:(BOOL)collapsed {
  // TODO(crbug.com/419346): Store in the browser state preference instead of
  // NSUserDefaults.
  DCHECK([self hasSectionForSectionIdentifier:sectionIdentifier]);
  NSString* sectionKey = [self.collapsedKeys objectForKey:@(sectionIdentifier)];
  DCHECK(sectionKey);
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary* collapsedSections =
      [defaults dictionaryForKey:kListModelCollapsedKey];
  NSMutableDictionary* newCollapsedSection =
      [NSMutableDictionary dictionaryWithDictionary:collapsedSections];
  NSNumber* value = [NSNumber numberWithBool:collapsed];
  [newCollapsedSection setValue:value forKey:sectionKey];
  [defaults setObject:newCollapsedSection forKey:kListModelCollapsedKey];
}

- (BOOL)sectionIsCollapsed:(NSInteger)sectionIdentifier {
  // TODO(crbug.com/419346): Store in the profile's preference instead of the
  // NSUserDefaults.
  DCHECK([self hasSectionForSectionIdentifier:sectionIdentifier]);
  NSString* sectionKey = [self.collapsedKeys objectForKey:@(sectionIdentifier)];
  if (!sectionKey)
    return NO;
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary* collapsedSections =
      [defaults dictionaryForKey:kListModelCollapsedKey];
  NSNumber* value = (NSNumber*)[collapsedSections valueForKey:sectionKey];
  return [value boolValue];
}

// |_collapsedKeys| lazy instantiation.
- (NSMutableDictionary*)collapsedKeys {
  if (!_collapsedKeys) {
    _collapsedKeys = [[NSMutableDictionary alloc] init];
  }
  return _collapsedKeys;
}

#pragma mark Private methods

// Returns the section for the given section identifier. If the section
// identifier is not found, NSNotFound is returned.
- (NSUInteger)internalSectionForIdentifier:(NSInteger)sectionIdentifier {
  return [_sectionIdentifiers indexOfObject:@(sectionIdentifier)];
}

// Returns the item for the given item type in the list of items, at the
// given index. If no item is found with the given type, NSNotFound is returned.
- (NSUInteger)itemForItemType:(NSInteger)itemType
               inSectionItems:(SectionItems*)sectionItems
                      atIndex:(NSUInteger)index {
  __block NSUInteger item = NSNotFound;
  __block NSUInteger indexInItemType = 0;
  [sectionItems
      enumerateObjectsUsingBlock:^(ListItem* obj, NSUInteger idx, BOOL* stop) {
        if (obj.type == itemType) {
          if (indexInItemType == index) {
            item = idx;
            *stop = YES;
          } else {
            indexInItemType++;
          }
        }
      }];
  return item;
}

// Returns |item|'s index among all the items of the same type in the given
// section items.  |item| must belong to |sectionItems|.
- (NSUInteger)indexInItemTypeForItem:(ListItem*)item
                      inSectionItems:(SectionItems*)sectionItems {
  DCHECK([sectionItems containsObject:item]);
  BOOL found = NO;
  NSUInteger indexInItemType = 0;
  for (ListItem* sectionItem in sectionItems) {
    if (sectionItem == item) {
      found = YES;
      break;
    }
    if (sectionItem.type == item.type) {
      indexInItemType++;
    }
  }
  DCHECK(found);
  return indexInItemType;
}

@end
