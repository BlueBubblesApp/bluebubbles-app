import 'dart:async';

import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:get/get.dart';

abstract class Queue extends GetxService {
  bool isProcessing = false;
  List<QueueItem> items = [];

  void queue(QueueItem item) {
    items.add(item);
    if (!isProcessing) processNextItem();
  }

  Future<void> processNextItem() async {
    if (items.isEmpty) {
      isProcessing = false;
      return;
    }

    isProcessing = true;
    QueueItem queued = items.removeAt(0);

    try {
      await handleQueueItem(queued);
      queued.completer?.complete();
    } catch (ex, stacktrace) {
      Logger.error("Failed to handle queued item! $ex");
      Logger.error(stacktrace.toString());
      queued.completer?.completeError(ex);
    }

    await processNextItem();
  }

  Future<void> handleQueueItem(QueueItem _);
}
