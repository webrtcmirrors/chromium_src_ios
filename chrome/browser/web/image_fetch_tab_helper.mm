// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web/image_fetch_tab_helper.h"

#include "base/base64.h"
#include "base/strings/stringprintf.h"
#include "base/strings/utf_string_conversions.h"
#include "base/values.h"
#import "ios/web/public/web_state/navigation_context.h"
#include "ios/web/public/web_thread.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

DEFINE_WEB_STATE_USER_DATA_KEY(ImageFetchTabHelper);

namespace {
// Command prefix for injected JavaScript.
const char kCommandPrefix[] = "imageFetch";
}

ImageFetchTabHelper::ImageFetchTabHelper(web::WebState* web_state)
    : web_state_(web_state), weak_ptr_factory_(this) {
  web_state->AddObserver(this);
  // BindRepeating cannot work on WeakPtr and function with return value, use
  // lambda as mediator.
  web_state->AddScriptCommandCallback(
      base::BindRepeating(
          [](base::WeakPtr<ImageFetchTabHelper> ptr,
             const base::DictionaryValue& message, const GURL& page_url,
             bool has_user_gesture, bool form_in_main_frame) {
            return ptr ? ptr->OnImageDataReceived(message) : true;
          },
          weak_ptr_factory_.GetWeakPtr()),
      kCommandPrefix);
}

ImageFetchTabHelper::~ImageFetchTabHelper() = default;

void ImageFetchTabHelper::DidStartNavigation(
    web::WebState* web_state,
    web::NavigationContext* navigation_context) {
  if (navigation_context->IsSameDocument()) {
    return;
  }
  for (auto&& pair : callbacks_)
    std::move(pair.second).Run(nullptr);
  callbacks_.clear();
}

void ImageFetchTabHelper::WebStateDestroyed(web::WebState* web_state) {
  web_state->RemoveScriptCommandCallback(kCommandPrefix);
  for (auto&& pair : callbacks_)
    std::move(pair.second).Run(nullptr);
  web_state->RemoveObserver(this);
  web_state_ = nullptr;
}

void ImageFetchTabHelper::GetImageData(const GURL& url,
                                       base::TimeDelta timeout,
                                       ImageDataCallback&& callback) {
  ++call_id_;
  DCHECK_EQ(callbacks_.count(call_id_), 0UL);
  callbacks_.insert({call_id_, std::move(callback)});

  web::WebThread::PostDelayedTask(
      web::WebThread::UI, FROM_HERE,
      base::BindRepeating(&ImageFetchTabHelper::OnImageDataTimeout,
                          weak_ptr_factory_.GetWeakPtr(), call_id_),
      timeout);

  std::string js =
      base::StringPrintf("__gCrWeb.imageFetch.getImageData(%d, '%s')", call_id_,
                         url.spec().c_str());

  web_state_->ExecuteJavaScript(base::UTF8ToUTF16(js));
}

// The expected message from JavaScript has format:
//
// For success:
//   {'command': 'image.getImageData',
//    'id': id_sent_to_gCrWeb_image_getImageData,
//    'data': image_data_in_base64}
//
// For failure:
//   {'command': 'image.getImageData',
//    'id': id_sent_to_gCrWeb_image_getImageData}
bool ImageFetchTabHelper::OnImageDataReceived(
    const base::DictionaryValue& message) {
  const base::Value* id_key = message.FindKey("id");
  if (!id_key || !id_key->is_double()) {
    return false;
  }
  int id_value = static_cast<int>(id_key->GetDouble());
  if (!callbacks_.count(id_value)) {
    return true;
  }
  ImageDataCallback callback = std::move(callbacks_[id_value]);
  callbacks_.erase(id_value);

  const base::Value* data = message.FindKey("data");
  std::string decoded_data;
  if (data && data->is_string() && !data->GetString().empty() &&
      base::Base64Decode(data->GetString(), &decoded_data)) {
    std::move(callback).Run(&decoded_data);
  } else {
    std::move(callback).Run(nullptr);
  }
  return true;
}

void ImageFetchTabHelper::OnImageDataTimeout(int call_id) {
  if (callbacks_.count(call_id)) {
    ImageDataCallback callback = std::move(callbacks_[call_id]);
    callbacks_.erase(call_id);
    std::move(callback).Run(nullptr);
  }
}