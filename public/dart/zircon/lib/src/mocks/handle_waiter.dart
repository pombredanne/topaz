// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of zircon_mocks;

// ignore_for_file: public_member_api_docs

typedef void AsyncWaitCallback(int status, int pending);

class HandleWaiter {
  // Private constructor.
  HandleWaiter._();

  void cancel() {}
}
