// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'todo_item_widget.dart';

/// The widget holding a list of Todos.
class TodoListWidget extends StatelessWidget {
  // TODO: Retrieve the list of items from Sledge.
  final List<TodoItem> _todoItems = new List<TodoItem>(3);

  @override
  Widget build(BuildContext context) {
    return new ListView(
        shrinkWrap: true,
        children: _todoItems
            .map((TodoItem todoItem) => new TodoItemWidget(todoItem))
            .toList());
  }
}
