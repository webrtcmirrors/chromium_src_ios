// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/translate/translate_popup_menu_coordinator.h"

#include "base/logging.h"
#include "base/mac/foundation_util.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/translate/language_selection_context.h"
#import "ios/chrome/browser/translate/language_selection_delegate.h"
#import "ios/chrome/browser/translate/language_selection_handler.h"
#import "ios/chrome/browser/translate/translate_option_selection_delegate.h"
#import "ios/chrome/browser/translate/translate_option_selection_handler.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_presenter.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_presenter_delegate.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_table_view_controller.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_table_view_controller_delegate.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_ui_constants.h"
#import "ios/chrome/browser/ui/translate/cells/select_language_popup_menu_item.h"
#import "ios/chrome/browser/ui/translate/translate_popup_menu_mediator.h"
#import "ios/chrome/browser/ui/util/layout_guide_names.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface TranslatePopupMenuCoordinator () <
    LanguageSelectionHandler,
    PopupMenuPresenterDelegate,
    PopupMenuTableViewControllerDelegate,
    TranslateOptionSelectionHandler>

// The WebStateList this coordinator observes.
@property(nonatomic, assign) WebStateList* webStateList;
// Presenter for the popup menu, managing the animations.
@property(nonatomic, strong) PopupMenuPresenter* presenter;
// Mediator for the popup menu.
@property(nonatomic, strong) TranslatePopupMenuMediator* mediator;
// ViewController for this coordinator.
@property(nonatomic, strong) PopupMenuTableViewController* viewController;
// Language selection delegate.
@property(nonatomic, weak) id<LanguageSelectionDelegate>
    languageSelectionDelegate;
// Translate option selection delegate.
@property(nonatomic, weak) id<TranslateOptionSelectionDelegate>
    translateOptionSelectionDelegate;
// YES if the coordinator has been started.
@property(nonatomic) BOOL started;

@end

@implementation TranslatePopupMenuCoordinator

- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                              browserState:
                                  (ios::ChromeBrowserState*)browserState
                              webStateList:(WebStateList*)webStateList {
  DCHECK(webStateList);
  self = [super initWithBaseViewController:viewController
                              browserState:browserState];
  if (self) {
    _webStateList = webStateList;
  }
  return self;
}

#pragma mark - ChromeCoordinator

- (void)start {
  if (self.started)
    return;

  self.mediator =
      [[TranslatePopupMenuMediator alloc] initWithSelectionHandler:self];
  self.mediator.webStateList = self.webStateList;

  self.started = YES;
}

- (void)stop {
  if (!self.started)
    return;

  [self dismissPopupMenu];
  [self.mediator disconnect];
  self.mediator = nil;
  self.webStateList = nullptr;
  self.presenter = nil;
  self.viewController = nil;
  self.languageSelectionDelegate = nil;
  self.translateOptionSelectionDelegate = nil;

  self.started = NO;
}

#pragma mark - LanguageSelectionHandler

- (void)showLanguageSelectorWithContext:(LanguageSelectionContext*)context
                               delegate:
                                   (id<LanguageSelectionDelegate>)delegate {
  if (self.presenter)
    return;

  self.translateOptionSelectionDelegate = nil;
  self.languageSelectionDelegate = delegate;

  self.mediator.type = TranslatePopupMenuTypeLanguageSelection;
  self.mediator.infobarDelegate = context.languageData;
  self.mediator.unavailableLanguageIndex = context.unavailableLanguageIndex;

  [self presentPopupMenu];
}

- (void)dismissLanguageSelector {
  if (!self.presenter)
    return;

  [self dismissPopupMenu];
}

#pragma mark - TranslateOptionSelectionHandler

- (void)
    showTranslateOptionSelectorWithInfoBarDelegate:
        (const translate::TranslateInfoBarDelegate*)infobarDelegate
                                          delegate:
                                              (id<TranslateOptionSelectionDelegate>)
                                                  delegate {
  if (self.presenter)
    return;

  self.translateOptionSelectionDelegate = delegate;
  self.languageSelectionDelegate = nil;

  self.mediator.type = TranslatePopupMenuTypeTranslateOptionSelection;
  self.mediator.infobarDelegate = infobarDelegate;
  self.mediator.unavailableLanguageIndex = -1;

  [self presentPopupMenu];
}

- (void)dismissTranslateOptionSelector {
  if (!self.presenter)
    return;

  [self dismissPopupMenu];
}

#pragma mark - PopupMenuTableViewControllerDelegate

- (void)popupMenuTableViewController:(PopupMenuTableViewController*)sender
                       didSelectItem:(TableViewItem<PopupMenuItem>*)item
                              origin:(CGPoint)origin {
  [self dismissPopupMenu];

  switch (item.actionIdentifier) {
    case PopupMenuActionSelectLanguage: {
      SelectLanguagePopupMenuItem* languageItem =
          base::mac::ObjCCastStrict<SelectLanguagePopupMenuItem>(item);
      [self.languageSelectionDelegate
          languageSelectorSelectedLanguage:base::SysNSStringToUTF8(
                                               languageItem.languageCode)];
      break;
    }
    case PopupMenuActionChangeTargetLanguage: {
      [self.translateOptionSelectionDelegate
          popupMenuTableViewControllerDidSelectTargetLanguageSelector:sender];
      break;
    }
    case PopupMenuActionAlwaysTranslateSourceLanguage: {
      [self.translateOptionSelectionDelegate
          popupMenuTableViewControllerDidSelectAlwaysTranslateSourceLanguage:
              sender];
      break;
    }
    case PopupMenuActionNeverTranslateSourceLanguage: {
      [self.translateOptionSelectionDelegate
          popupMenuTableViewControllerDidSelectNeverTranslateSourceLanguage:
              sender];
      break;
    }
    case PopupMenuActionNeverTranslateSite: {
      [self.translateOptionSelectionDelegate
          popupMenuTableViewControllerDidSelectNeverTranslateSite:sender];
      break;
    }
    case PopupMenuActionChangeSourceLanguage: {
      [self.translateOptionSelectionDelegate
          popupMenuTableViewControllerDidSelectSourceLanguageSelector:sender];
      break;
    }
    default:
      NOTREACHED() << "Unexpected identifier";
      break;
  }
}

#pragma mark - ContainedPresenterDelegate

- (void)containedPresenterDidPresent:(id<ContainedPresenter>)presenter {
  // noop.
}

- (void)containedPresenterDidDismiss:(id<ContainedPresenter>)presenter {
  // noop.
}

#pragma mark - PopupMenuPresenterDelegate

- (void)popupMenuPresenterWillDismiss:(PopupMenuPresenter*)presenter {
  [self dismissPopupMenu];
  [self.languageSelectionDelegate languageSelectorClosedWithoutSelection];
  [self.translateOptionSelectionDelegate
      popupMenuPresenterDidCloseWithoutSelection:presenter];
}

#pragma mark - Private

// Presents a popup menu with animation.
- (void)presentPopupMenu {
  self.viewController = [[PopupMenuTableViewController alloc] init];
  self.viewController.baseViewController = self.baseViewController;
  self.viewController.delegate = self;

  self.mediator.consumer = self.viewController;

  self.presenter = [[PopupMenuPresenter alloc] init];
  self.presenter.baseViewController = self.baseViewController;
  self.presenter.presentedViewController = self.viewController;
  self.presenter.guideName = kTranslateInfobarOptionsGuide;
  self.presenter.delegate = self;
  [self.presenter prepareForPresentation];
  [self.presenter presentAnimated:YES];
}

- (void)dismissPopupMenu {
  [self.presenter dismissAnimated:NO];
  self.presenter = nil;
}

@end
