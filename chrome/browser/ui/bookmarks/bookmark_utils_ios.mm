// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bookmarks/bookmark_utils_ios.h"

#include <stdint.h>

#include <memory>
#include <vector>

#include "base/hash.h"
#include "base/i18n/string_compare.h"
#include "base/mac/bind_objc_block.h"
#include "base/memory/ptr_util.h"
#include "base/metrics/user_metrics_action.h"
#include "base/strings/sys_string_conversions.h"
#include "base/strings/utf_string_conversions.h"
#include "components/bookmarks/browser/bookmark_model.h"
#include "components/query_parser/query_parser.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/bookmarks/bookmarks_utils.h"
#include "ios/chrome/browser/experimental_flags.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_collection_cells.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_menu_item.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_position_cache.h"
#include "ios/chrome/browser/ui/bookmarks/undo_manager_wrapper.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/third_party/material_components_ios/src/components/Snackbar/src/MaterialSnackbar.h"
#include "third_party/skia/include/core/SkColor.h"
#include "ui/base/l10n/l10n_util.h"
#include "ui/base/l10n/l10n_util_mac.h"
#include "ui/base/models/tree_node_iterator.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using bookmarks::BookmarkNode;

namespace bookmark_utils_ios {

namespace {

const BookmarkNode* FindFolderById(bookmarks::BookmarkModel* model,
                                   int64_t id) {
  ui::TreeNodeIterator<const BookmarkNode> iterator(model->root_node());
  while (iterator.has_next()) {
    const BookmarkNode* bookmark = iterator.Next();
    if (bookmark->id() == id && bookmark->is_folder())
      return bookmark;
  }
  return NULL;
}

const SkColor colors[] = {
    0xE64A19, 0xF09300, 0xAFB42B, 0x689F38,
    0x0B8043, 0x0097A7, 0x7B1FA2, 0xC2185B,
};

UIColor* ColorFromSkColor(SkColor color) {
  return [UIColor colorWithRed:SkColorGetR(color) / 255.0f
                         green:SkColorGetG(color) / 255.0f
                          blue:SkColorGetB(color) / 255.0f
                         alpha:1.0];
}

}  // namespace

// This is the distance from the left edge of the screen to the left edge of a
// 24x24 image.
const CGFloat menuMargin = 16;
const CGFloat titleMargin = 73;
const CGFloat titleToIconDistance = 33;
const CGFloat menuAnimationDuration = 0.2;
NSString* const kPositionCacheKey = @"BookmarksStarsPositionCacheKey";
NSString* const kBookmarksSnackbarCategory = @"BookmarksSnackbarCategory";

NSString* TitleForBookmarkNode(const BookmarkNode* node) {
  NSString* title;

  if (node->type() == BookmarkNode::BOOKMARK_BAR) {
    title = l10n_util::GetNSString(IDS_IOS_BOOKMARK_NEW_BOOKMARKS_BAR_TITLE);
  } else if (node->type() == BookmarkNode::MOBILE) {
    title = l10n_util::GetNSString(IDS_BOOKMARK_BAR_MOBILE_FOLDER_NAME);
  } else if (node->type() == BookmarkNode::OTHER_NODE) {
    title = l10n_util::GetNSString(IDS_BOOKMARK_BAR_OTHER_FOLDER_NAME);
  } else {
    title = base::SysUTF16ToNSString(node->GetTitle());
  }

  // Assign a default bookmark name if it is at top level.
  if (node->is_root() && ![title length])
    title = l10n_util::GetNSString(IDS_SYNC_DATATYPE_BOOKMARKS);

  return title;
}

UIColor* DefaultColor(const GURL& url) {
  uint32_t hash = base::Hash(url.possibly_invalid_spec());
  SkColor color = colors[hash % arraysize(colors)];
  return ColorFromSkColor(color);
}

NSString* subtitleForBookmarkNode(const BookmarkNode* node) {
  if (node->is_url())
    return base::SysUTF8ToNSString(node->url().host());

  int childCount = node->GetTotalNodeCount() - 1;
  NSString* subtitle;
  if (childCount == 0) {
    subtitle = l10n_util::GetNSString(IDS_IOS_BOOKMARK_NO_ITEM_COUNT);
  } else if (childCount == 1) {
    subtitle = l10n_util::GetNSString(IDS_IOS_BOOKMARK_ONE_ITEM_COUNT);
  } else {
    NSString* childCountString = [NSString stringWithFormat:@"%d", childCount];
    subtitle =
        l10n_util::GetNSStringF(IDS_IOS_BOOKMARK_ITEM_COUNT,
                                base::SysNSStringToUTF16(childCountString));
  }
  return subtitle;
}

UIColor* mainBackgroundColor() {
  if (IsIPadIdiom()) {
    return [UIColor whiteColor];
  } else {
    return [UIColor colorWithWhite:242 / 255.0 alpha:1.0];
  }
}

UIColor* menuBackgroundColor() {
  if (bookmarkMenuIsInSlideInPanel()) {
    return [UIColor whiteColor];
  } else {
    return [UIColor clearColor];
  }
}

UIColor* darkTextColor() {
  return [UIColor colorWithWhite:33 / 255.0 alpha:1.0];
}

UIColor* lightTextColor() {
  return [UIColor colorWithWhite:118 / 255.0 alpha:1.0];
}

UIColor* highlightedDarkTextColor() {
  return [UIColor colorWithWhite:102 / 255.0 alpha:1.0];
}

UIColor* blueColor() {
  return [UIColor colorWithRed:66 / 255.0
                         green:129 / 255.0
                          blue:244 / 255.0
                         alpha:1];
}

UIColor* GrayColor() {
  return [UIColor colorWithWhite:242 / 255.0 alpha:1.0];
}

UIColor* separatorColor() {
  return [UIColor colorWithWhite:214 / 255.0 alpha:1.0];
}

UIColor* FolderLabelColor() {
  return [UIColor colorWithWhite:38 / 255.0 alpha:0.8];
}

CGFloat StatusBarHeight() {
  CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
  CGRect statusBarWindowRect =
      [[UIApplication sharedApplication].keyWindow convertRect:statusBarFrame
                                                    fromWindow:nil];
  if (UIInterfaceOrientationIsPortrait(
          [UIApplication sharedApplication].statusBarOrientation)) {
    return CGRectGetHeight(statusBarWindowRect);
  } else {
    return CGRectGetWidth(statusBarWindowRect);
  }
}

BOOL bookmarkMenuIsInSlideInPanel() {
  return !IsIPadIdiom() || IsCompactTablet();
}

UIView* dropShadowWithWidth(CGFloat width) {
  UIImage* shadowImage = [UIImage imageNamed:@"bookmark_bar_shadow"];
  UIImageView* shadow = [[UIImageView alloc] initWithImage:shadowImage];
  CGRect shadowFrame = CGRectMake(0, 0, width, 4);
  shadow.frame = shadowFrame;
  shadow.autoresizingMask =
      UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
  return shadow;
}

#pragma mark - Updating Bookmarks

// Deletes all subnodes of |node|, including |node|, that are in |bookmarks|.
void DeleteBookmarks(const std::set<const BookmarkNode*>& bookmarks,
                     bookmarks::BookmarkModel* model,
                     const BookmarkNode* node);

// Presents a toast which will undo the changes made to the bookmark model if
// the user presses the undo button, and the UndoManagerWrapper allows the undo
// to go through.
void PresentUndoToastWithWrapper(UndoManagerWrapper* wrapper, NSString* text);

void CreateOrUpdateBookmarkWithUndoToast(
    const BookmarkNode* node,
    NSString* title,
    const GURL& url,
    const BookmarkNode* folder,
    bookmarks::BookmarkModel* bookmark_model,
    ios::ChromeBrowserState* browser_state) {
  DCHECK(!node || node->is_url());
  base::string16 titleString = base::SysNSStringToUTF16(title);

  // If the bookmark has no changes supporting Undo, just bail out.
  if (node && node->GetTitle() == titleString && node->url() == url &&
      node->parent() == folder) {
    return;
  }

  // Secondly, create an Undo group for all undoable actions.
  UndoManagerWrapper* wrapper =
      [[UndoManagerWrapper alloc] initWithBrowserState:browser_state];

  // Create or update the bookmark.
  [wrapper startGroupingActions];

  // Save the bookmark information.
  if (!node) {  // Create a new bookmark.
    bookmark_model->client()->RecordAction(
        base::UserMetricsAction("BookmarkAdded"));
    node =
        bookmark_model->AddURL(folder, folder->child_count(), titleString, url);
  } else {  // Update the information.
    bookmark_model->SetTitle(node, titleString);
    bookmark_model->SetURL(node, url);

    DCHECK(folder);
    DCHECK(!folder->HasAncestor(node));
    if (node->parent() != folder) {
      bookmark_model->Move(node, folder, folder->child_count());
    }
    DCHECK(node->parent() == folder);
  }

  [wrapper stopGroupingActions];
  [wrapper resetUndoManagerChanged];

  NSString* text =
      l10n_util::GetNSString((node) ? IDS_IOS_BOOKMARK_NEW_BOOKMARK_UPDATED
                                    : IDS_IOS_BOOKMARK_NEW_BOOKMARK_CREATED);
  PresentUndoToastWithWrapper(wrapper, text);
}

void PresentUndoToastWithWrapper(UndoManagerWrapper* wrapper, NSString* text) {
  // Create the block that will be executed if the user taps the undo button.
  MDCSnackbarMessageAction* action = [[MDCSnackbarMessageAction alloc] init];
  action.handler = ^{
    if (![wrapper hasUndoManagerChanged])
      [wrapper undo];
  };

  action.title = l10n_util::GetNSString(IDS_IOS_BOOKMARK_NEW_UNDO_BUTTON_TITLE);
  action.accessibilityIdentifier = @"Undo";
  action.accessibilityLabel =
      l10n_util::GetNSString(IDS_IOS_BOOKMARK_NEW_UNDO_BUTTON_TITLE);
  TriggerHapticFeedbackForNotification(UINotificationFeedbackTypeSuccess);
  MDCSnackbarMessage* message = [MDCSnackbarMessage messageWithText:text];
  message.action = action;
  message.category = kBookmarksSnackbarCategory;
  [MDCSnackbarManager showMessage:message];
}

void DeleteBookmarks(const std::set<const BookmarkNode*>& bookmarks,
                     bookmarks::BookmarkModel* model) {
  DCHECK(model->loaded());
  DeleteBookmarks(bookmarks, model, model->root_node());
}

void DeleteBookmarks(const std::set<const BookmarkNode*>& bookmarks,
                     bookmarks::BookmarkModel* model,
                     const BookmarkNode* node) {
  // Delete children in reverse order, so that the index remains valid.
  for (int i = node->child_count() - 1; i >= 0; --i) {
    DeleteBookmarks(bookmarks, model, node->GetChild(i));
  }

  if (bookmarks.find(node) != bookmarks.end())
    model->Remove(node);
}

void DeleteBookmarksWithUndoToast(const std::set<const BookmarkNode*>& nodes,
                                  bookmarks::BookmarkModel* model,
                                  ios::ChromeBrowserState* browser_state) {
  size_t nodeCount = nodes.size();
  DCHECK_GT(nodeCount, 0u);

  UndoManagerWrapper* wrapper =
      [[UndoManagerWrapper alloc] initWithBrowserState:browser_state];

  // Delete the selected bookmarks.
  [wrapper startGroupingActions];
  bookmark_utils_ios::DeleteBookmarks(nodes, model);
  [wrapper stopGroupingActions];
  [wrapper resetUndoManagerChanged];

  NSString* text = nil;

  if (nodeCount == 1) {
    text = l10n_util::GetNSString(IDS_IOS_BOOKMARK_NEW_SINGLE_BOOKMARK_DELETE);
  } else {
    NSString* countString = [NSString stringWithFormat:@"%zu", nodeCount];
    text =
        l10n_util::GetNSStringF(IDS_IOS_BOOKMARK_NEW_MULTIPLE_BOOKMARK_DELETE,
                                base::SysNSStringToUTF16(countString));
  }

  PresentUndoToastWithWrapper(wrapper, text);
}

bool MoveBookmarks(const std::set<const BookmarkNode*>& bookmarks,
                   bookmarks::BookmarkModel* model,
                   const BookmarkNode* folder) {
  bool didPerformMove = false;

  // Calling Move() on the model will triger observer methods to fire, one of
  // them may modify the passed in |bookmarks|. To protect against this scenario
  // a copy of the set is made first.
  const std::set<const BookmarkNode*> bookmarks_copy(bookmarks);
  for (const BookmarkNode* node : bookmarks_copy) {
    // The bookmarks model can change under us at any time, so we can't make
    // any assumptions.
    if (folder->HasAncestor(node))
      continue;
    if (node->parent() != folder) {
      model->Move(node, folder, folder->child_count());
      didPerformMove = true;
    }
  }
  return didPerformMove;
}

void MoveBookmarksWithUndoToast(const std::set<const BookmarkNode*>& nodes,
                                bookmarks::BookmarkModel* model,
                                const BookmarkNode* folder,
                                ios::ChromeBrowserState* browser_state) {
  size_t nodeCount = nodes.size();
  DCHECK_GT(nodeCount, 0u);

  UndoManagerWrapper* wrapper =
      [[UndoManagerWrapper alloc] initWithBrowserState:browser_state];

  // Move the selected bookmarks.
  [wrapper startGroupingActions];
  bool didPerformMove = bookmark_utils_ios::MoveBookmarks(nodes, model, folder);
  [wrapper stopGroupingActions];
  [wrapper resetUndoManagerChanged];

  if (!didPerformMove)
    return;  // Don't present a snackbar when no real move as happened.

  NSString* text = nil;
  if (nodeCount == 1) {
    text = l10n_util::GetNSString(IDS_IOS_BOOKMARK_NEW_SINGLE_BOOKMARK_MOVE);
  } else {
    NSString* countString = [NSString stringWithFormat:@"%zu", nodeCount];
    text = l10n_util::GetNSStringF(IDS_IOS_BOOKMARK_NEW_MULTIPLE_BOOKMARK_MOVE,
                                   base::SysNSStringToUTF16(countString));
  }

  PresentUndoToastWithWrapper(wrapper, text);
}

const BookmarkNode* defaultMoveFolder(
    const std::set<const BookmarkNode*>& bookmarks,
    bookmarks::BookmarkModel* model) {
  if (bookmarks.size() == 0)
    return model->mobile_node();
  const BookmarkNode* firstParent = (*(bookmarks.begin()))->parent();
  for (const BookmarkNode* node : bookmarks) {
    if (node->parent() != firstParent)
      return model->mobile_node();
  }

  return firstParent;
}

#pragma mark - Segregation of nodes by time.

NodesSection::NodesSection() {}

NodesSection::~NodesSection() {}

void segregateNodes(
    const NodeVector& vector,
    std::vector<std::unique_ptr<NodesSection>>& nodesSectionVector) {
  nodesSectionVector.clear();

  // Make a localized date formatter.
  NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"MMMM yyyy"];
  // Segregate nodes by creation date.
  // Nodes that were created in the same month are grouped together.
  for (auto* node : vector) {
    @autoreleasepool {
      base::Time dateAdded = node->date_added();
      base::TimeDelta delta = dateAdded - base::Time::UnixEpoch();
      NSDate* date =
          [[NSDate alloc] initWithTimeIntervalSince1970:delta.InSeconds()];
      NSString* dateString = [formatter stringFromDate:date];
      const std::string timeRepresentation =
          base::SysNSStringToUTF8(dateString);

      BOOL found = NO;
      for (const auto& nodesSection : nodesSectionVector) {
        if (nodesSection->timeRepresentation == timeRepresentation) {
          nodesSection->vector.push_back(node);
          found = YES;
          break;
        }
      }

      if (found)
        continue;

      // No NodesSection found.
      auto nodesSection = base::MakeUnique<NodesSection>();
      nodesSection->time = dateAdded;
      nodesSection->timeRepresentation = timeRepresentation;
      nodesSection->vector.push_back(node);
      nodesSectionVector.push_back(std::move(nodesSection));
    }
  }

  // Sort the NodesSections.
  std::sort(nodesSectionVector.begin(), nodesSectionVector.end(),
            [](const std::unique_ptr<NodesSection>& n1,
               const std::unique_ptr<NodesSection>& n2) {
              return n1->time > n2->time;
            });

  // For each NodesSection, sort the nodes inside.
  for (const auto& nodesSection : nodesSectionVector) {
    std::sort(nodesSection->vector.begin(), nodesSection->vector.end(),
              [](const BookmarkNode* n1, const BookmarkNode* n2) {
                return n1->date_added() > n2->date_added();
              });
  }
}

#pragma mark - Useful bookmark manipulation.

// Adds all children of |folder| that are not obstructed to |results|. They are
// placed immediately after |folder|, using a depth-first, then alphabetically
// ordering. |results| must contain |folder|.
void UpdateFoldersFromNode(const BookmarkNode* folder,
                           NodeVector* results,
                           const NodeSet& obstructions);
// Returns whether |folder| has an ancestor in any of the nodes in
// |bookmarkNodes|.
bool FolderHasAncestorInBookmarkNodes(const BookmarkNode* folder,
                                      const NodeSet& bookmarkNodes);
// Returns true if the node is not a folder, is not visible, or is an ancestor
// of any of the nodes in |obstructions|.
bool IsObstructed(const BookmarkNode* node, const NodeSet& obstructions);

namespace {
// Comparator used to sort bookmarks. No folders are allowed.
class FolderNodeComparator : public std::binary_function<const BookmarkNode*,
                                                         const BookmarkNode*,
                                                         bool> {
 public:
  explicit FolderNodeComparator(icu::Collator* collator)
      : collator_(collator) {}

  // Returns true if |n1| preceeds |n2|.
  bool operator()(const BookmarkNode* n1, const BookmarkNode* n2) {
    if (!collator_)
      return n1->GetTitle() < n2->GetTitle();
    return base::i18n::CompareString16WithCollator(*collator_, n1->GetTitle(),
                                                   n2->GetTitle()) == UCOL_LESS;
  }

 private:
  icu::Collator* collator_;
};
};

bool FolderHasAncestorInBookmarkNodes(const BookmarkNode* folder,
                                      const NodeSet& bookmarkNodes) {
  DCHECK(folder->is_folder());
  for (const BookmarkNode* node : bookmarkNodes) {
    if (folder->HasAncestor(node))
      return true;
  }
  return false;
}

bool IsObstructed(const BookmarkNode* node, const NodeSet& obstructions) {
  if (!node->is_folder())
    return true;
  if (!node->IsVisible())
    return true;
  if (FolderHasAncestorInBookmarkNodes(node, obstructions))
    return true;
  return false;
}

void UpdateFoldersFromNode(const BookmarkNode* folder,
                           NodeVector* results,
                           const NodeSet& obstructions) {
  std::vector<const BookmarkNode*> directDescendants;
  for (int i = 0; i < folder->child_count(); ++i) {
    const BookmarkNode* subfolder = folder->GetChild(i);
    if (IsObstructed(subfolder, obstructions))
      continue;

    directDescendants.push_back(subfolder);
  }

  bookmark_utils_ios::SortFolders(&directDescendants);

  auto it = std::find(results->begin(), results->end(), folder);
  DCHECK(it != results->end());
  ++it;
  results->insert(it, directDescendants.begin(), directDescendants.end());

  // Recursively perform the operation on each direct descendant.
  for (auto* node : directDescendants)
    UpdateFoldersFromNode(node, results, obstructions);
}

void SortFolders(NodeVector* vector) {
  UErrorCode error = U_ZERO_ERROR;
  std::unique_ptr<icu::Collator> collator(icu::Collator::createInstance(error));
  if (U_FAILURE(error))
    collator.reset(NULL);
  std::sort(vector->begin(), vector->end(),
            FolderNodeComparator(collator.get()));
}

NodeVector VisibleNonDescendantNodes(const NodeSet& obstructions,
                                     bookmarks::BookmarkModel* model) {
  NodeVector results;

  NodeVector primaryNodes = PrimaryPermanentNodes(model);
  NodeVector filteredPrimaryNodes;
  for (auto* node : primaryNodes) {
    if (IsObstructed(node, obstructions))
      continue;

    filteredPrimaryNodes.push_back(node);
  }

  // Copy the results over.
  results = filteredPrimaryNodes;

  // Iterate over a static copy of the filtered, root folders.
  for (auto* node : filteredPrimaryNodes)
    UpdateFoldersFromNode(node, &results, obstructions);

  return results;
}

// Whether |vector1| contains only elements of |vector2| in the same order.
BOOL IsSubvectorOfNodes(const NodeVector& vector1, const NodeVector& vector2) {
  NodeVector::const_iterator it = vector2.begin();
  // Scan the first vector.
  for (const auto* node : vector1) {
    // Look for a match in the rest of the second vector. When found, advance
    // the iterator on vector2 to only focus on the remaining part of vector2,
    // so that ordering is verified.
    it = std::find(it, vector2.end(), node);
    if (it == vector2.end())
      return NO;
    // If found in vector2, advance the iterator so that the match is only
    // matched once.
    it++;
  }
  return YES;
}

// Returns the indices in |vector2| of the items in |vector2| that are not
// present in |vector1|.
// |vector1| MUST be a subvector of |vector2| in the sense of |IsSubvector|.
std::vector<NodeVector::size_type> MissingNodesIndices(
    const NodeVector& vector1,
    const NodeVector& vector2) {
  DCHECK(IsSubvectorOfNodes(vector1, vector2))
      << "Can't compute missing nodes between nodes among which the first is "
         "not a subvector of the second.";

  std::vector<NodeVector::size_type> missingNodesIndices;
  // Keep an iterator on vector1.
  NodeVector::const_iterator it1 = vector1.begin();
  // Scan vector2, looking for vector1 elements.
  for (NodeVector::size_type i2 = 0; i2 != vector2.size(); i2++) {
    // When vector1 has been fully traversed, all remaining elements of vector2
    // are to be added to the missing nodes.
    // Otherwise, while the element of vector2 is not equal to the element the
    // iterator on vector1 is pointing to, add vector2 elements to the missing
    // nodes.
    if (it1 == vector1.end() || vector2[i2] != *it1) {
      missingNodesIndices.push_back(i2);
    } else {
      // When there is a match between vector2 and vector1, advance the iterator
      // of vector1.
      it1++;
    }
  }
  return missingNodesIndices;
}

#pragma mark - Cache position in collection view.

void CachePosition(CGFloat position, BookmarkMenuItem* item) {
  BookmarkPositionCache* cache = nil;
  switch (item.type) {
    case bookmarks::MenuItemFolder:
      cache = [BookmarkPositionCache
          cacheForMenuItemFolderWithPosition:position
                                    folderId:item.folder->id()];
      break;
    case bookmarks::MenuItemDivider:
    case bookmarks::MenuItemSectionHeader:
      NOTREACHED();
      break;
  }

  // TODO(crbug.com/388789): remove the use of NSUserDefaults.
  NSData* data = [NSKeyedArchiver archivedDataWithRootObject:cache];
  [[NSUserDefaults standardUserDefaults] setObject:data
                                            forKey:kPositionCacheKey];
}

BOOL GetPositionCache(bookmarks::BookmarkModel* model,
                      BookmarkMenuItem** item,
                      CGFloat* position) {
  DCHECK(model->loaded());
  DCHECK(item);
  DCHECK(position);

  // TODO(crbug.com/388789): remove the use of NSUserDefaults.
  NSData* data =
      [[NSUserDefaults standardUserDefaults] objectForKey:kPositionCacheKey];
  if (!data || ![data isKindOfClass:[NSData class]])
    return NO;
  BookmarkPositionCache* cache =
      [NSKeyedUnarchiver unarchiveObjectWithData:data];
  if (!cache)
    return NO;

  switch (cache.type) {
    case bookmarks::MenuItemFolder: {
      const BookmarkNode* bookmark = FindFolderById(model, cache.folderId);
      if (!bookmark)
        return NO;
      const BookmarkNode* parent = RootLevelFolderForNode(bookmark, model);
      if (!parent)
        parent = bookmark;
      *item =
          [BookmarkMenuItem folderMenuItemForNode:bookmark rootAncestor:parent];
      break;
    }
    case bookmarks::MenuItemDivider:
    case bookmarks::MenuItemSectionHeader:
      NOTREACHED();
      return NO;
  }

  *position = cache.position;
  return YES;
}

void ClearPositionCache() {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPositionCacheKey];
}

}  // namespace bookmark_utils_ios
