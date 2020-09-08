import 'package:flutter/material.dart';

class QueueItem {
  String event;
  dynamic item;

  QueueItem({this.event, this.item});
}

abstract class QueueManager {
  bool isProcessing = false;
  List<QueueItem> queue = [];

  /// Adds an item to the queue and kicks off the processing (if required)
  Future<void> add(QueueItem item) async {
    // Add the item to the queue, no matter what
    this.queue.add(item);

    // Only process this item if we aren't currently processing
    if (!this.isProcessing) this.processNextItem();
  }

  /// Processes the next item in the queue
  Future<void> processNextItem() async {
    // If there are no queued items, we are done processing
    if (this.queue.length == 0) {
      this.isProcessing = false;
      return;
    }

    // Start processing top item
    this.isProcessing = true;
    QueueItem queued = this.queue.removeAt(0);

    try {
      await beforeProcessing(queued, {});
      await handleQueueItem(queued);
      await afterProcessing(queued, {});
    } catch (ex) {
      debugPrint("Failed to handle queued item!");
    }

    // Process the next item
    await processNextItem();
  }

  /// Performs pre-processing before the [item] is handled by the implementer.
  /// You can pass any number of [params] using the second Map parameter
  Future<void> beforeProcessing(QueueItem item, Map params) async {
    /* Do Nothing */
  }

  /// Handles the currently passed [item] from the queue
  Future<void> handleQueueItem(QueueItem item);

  /// Performs post-processing before the [item] is handled by the implementer.
  /// You can pass any number of [params] using the second Map parameter
  Future<void> afterProcessing(QueueItem item, Map params) async {
    /* Do Nothing */
  }
}
