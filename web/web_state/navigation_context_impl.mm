// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/web/web_state/navigation_context_impl.h"

#include "base/memory/ptr_util.h"
#include "net/http/http_response_headers.h"

namespace web {

// static
std::unique_ptr<NavigationContext>
NavigationContextImpl::CreateNavigationContext(
    WebState* web_state,
    const GURL& url,
    const scoped_refptr<net::HttpResponseHeaders>& response_headers) {
  std::unique_ptr<NavigationContext> resut(
      new NavigationContextImpl(web_state, url, false /* is_same_document */,
                                false /* is_error_page */, response_headers));
  return resut;
}

// static
std::unique_ptr<NavigationContext>
NavigationContextImpl::CreateSameDocumentNavigationContext(WebState* web_state,
                                                           const GURL& url) {
  std::unique_ptr<NavigationContext> result(new NavigationContextImpl(
      web_state, url, true /* is_same_document */, false /* is_error_page */,
      nullptr /* response_headers */));
  return result;
}

// static
std::unique_ptr<NavigationContext>
NavigationContextImpl::CreateErrorPageNavigationContext(
    WebState* web_state,
    const GURL& url,
    const scoped_refptr<net::HttpResponseHeaders>& response_headers) {
  std::unique_ptr<NavigationContext> result(
      new NavigationContextImpl(web_state, url, false /* is_same_document */,
                                true /* is_error_page */, response_headers));
  return result;
}

WebState* NavigationContextImpl::GetWebState() {
  return web_state_;
}

const GURL& NavigationContextImpl::GetUrl() const {
  return url_;
}

bool NavigationContextImpl::IsSameDocument() const {
  return is_same_document_;
}

bool NavigationContextImpl::IsErrorPage() const {
  return is_error_page_;
}

net::HttpResponseHeaders* NavigationContextImpl::GetResponseHeaders() const {
  return response_headers_.get();
}

NavigationContextImpl::NavigationContextImpl(
    WebState* web_state,
    const GURL& url,
    bool is_same_document,
    bool is_error_page,
    const scoped_refptr<net::HttpResponseHeaders>& response_headers)
    : web_state_(web_state),
      url_(url),
      is_same_document_(is_same_document),
      is_error_page_(is_error_page),
      response_headers_(response_headers) {}

NavigationContextImpl::~NavigationContextImpl() = default;

}  // namespace web
