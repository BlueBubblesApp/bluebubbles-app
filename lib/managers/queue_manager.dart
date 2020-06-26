import 'dart:async';
import 'dart:convert';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:flutter/widgets.dart';

class QueueManager {
  factory QueueManager() {
    return _manager;
  }

  static final QueueManager _manager = QueueManager._internal();

  QueueManager._internal();

  List<Map<String, String>> queue;
  Timer timer;

  void init() async {
    this.flush();
    this.start();
  }

  Future<void> start() async {
    this.timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      // Copy current queue and reset master
      List<Map<String, String>> copy = [...this.queue];
      this.flush();

      if (copy.length > 0) {
        debugPrint("Handling ${copy.length} queued items");
      }

      // Handle each event in the queue
      for (int i = 0; i < copy.length; i++) {
        await this.handleEvent(copy[i]["event"], copy[i]["message"]);
      }
    });
  }

  Future<void> handleEvent(String event, String jsonData) async {
    if (event == "updated-message") {
      await ActionHandler.handleUpdatedMessage(jsonDecode(jsonData));
    } else if (event == "new-message") {
      await ActionHandler.handleMessage(jsonDecode(jsonData));
    } else if (event == "new-notification") {
      ActionHandler.createNotification(jsonDecode(jsonData));
    }
  }

  addEvent(String event, String message) {
    this.queue.add({"event": event, "message": message});
  }

  flush() {
    this.queue = [];
  }

  stop() {
    this.timer.cancel();
  }
}
