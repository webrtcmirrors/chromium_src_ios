// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PAYMENTS_SHIPPING_OPTION_SELECTION_COORDINATOR_H_
#define IOS_CHROME_BROWSER_PAYMENTS_SHIPPING_OPTION_SELECTION_COORDINATOR_H_

#import <UIKit/UIKit.h>
#include <vector>

#import "ios/chrome/browser/chrome_coordinator.h"
#include "ios/chrome/browser/payments/payment_request.h"
#include "ios/web/public/payments/payment_request.h"

@class ShippingOptionSelectionCoordinator;

// Delegate protocol for ShippingOptionSelectionCoordinator.
@protocol ShippingOptionSelectionCoordinatorDelegate<NSObject>

// Notifies the delegate that the user has selected a shipping option.
- (void)shippingOptionSelectionCoordinator:
            (ShippingOptionSelectionCoordinator*)coordinator
                   didSelectShippingOption:
                       (web::PaymentShippingOption*)shippingOption;

// Notifies the delegate that the user has chosen to return to the previous
// screen without making a selection.
- (void)shippingOptionSelectionCoordinatorDidReturn:
    (ShippingOptionSelectionCoordinator*)coordinator;

@end

// Coordinator responsible for creating and presenting the shipping option
// selection view controller. This view controller will be presented by the view
// controller provided in the initializer.
@interface ShippingOptionSelectionCoordinator : ChromeCoordinator

// The PaymentRequest object owning an instance of web::PaymentRequest as
// provided by the page invoking the Payment Request API. This is a weak
// reference and should outlive this class.
@property(nonatomic, assign) PaymentRequest* paymentRequest;

// The delegate to be notified when the user selects a shipping option or
// returns without selecting one.
@property(nonatomic, weak) id<ShippingOptionSelectionCoordinatorDelegate>
    delegate;

@end

#endif  // IOS_CHROME_BROWSER_PAYMENTS_SHIPPING_OPTION_SELECTION_COORDINATOR_H_
