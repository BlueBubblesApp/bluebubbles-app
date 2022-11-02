import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

enum SyncStatus { IDLE, IN_PROGRESS, STOPPING, COMPLETED_SUCCESS, COMPLETED_ERROR }

abstract class SyncManager {
  String name;

  /// The current status of the sync
  Rx<SyncStatus> status = SyncStatus.IDLE.obs;

  /// If the sync errors out, this will be filled
  String? error;

  /// The current progress of the sync
  RxDouble progress = 0.0.obs;

  /// When the sync started
  DateTime? startedAt;

  /// When the sync ended
  DateTime? endedAt;

  /// So we can track the progress of the
  Completer<void>? completer;

  bool saveLogs;

  // Store any log output here
  RxList<Tuple2<LogLevel, String>> output = <Tuple2<LogLevel, String>>[].obs;

  SyncManager(this.name, {this.saveLogs = false});

  /// Start the sync
  Future<void> start() async {
    startedAt = DateTime.now().toUtc();
    setProgress(0, 1);
    error = null;

    Logger.info('$name Sync is starting...', tag: 'SyncManager');
  }

  Future<void> stop() async {
    if (completer != null && !completer!.isCompleted) {
      status.value = SyncStatus.STOPPING;
      await completer!.future;
    }

    completeWithError('$name Sync was force stopped');
  }

  void setProgress(int amount, int total) {
    if (total <= 0) {
      progress.value = 0.0;
    } else if (amount >= total) {
      progress.value = 1.0;
    } else {
      progress.value = double.parse((amount / total).toStringAsFixed(2));
    }
  }

  void setProgressExact(double percent) {
    if (percent <= 0) {
      progress.value = 0.0;
    } else if (percent > 1.0) {
      progress.value = 1.0;
    } else {
      progress.value = double.parse(percent.toStringAsFixed(2));
    }
  }

  void addToOutput(String log, {LogLevel level = LogLevel.INFO}) {
    output.add(Tuple2(level, log));

    if (level == LogLevel.ERROR) {
      Logger.error(log, tag: "SyncManager");
    } else if (level == LogLevel.WARN) {
      Logger.warn(log, tag: "SyncManager");
    } else {
      Logger.info(log, tag: "SyncManager");
    }
  }

  Future<void> complete() async {
    if (completer != null && !completer!.isCompleted) {
      completer!.complete();
    }

    setProgress(1, 1);
    status.value = SyncStatus.COMPLETED_SUCCESS;
    endedAt = DateTime.now().toUtc();
    Logger.info(
        '$name Sync has completed. Elapsed Time: ${endedAt!.millisecondsSinceEpoch - startedAt!.millisecondsSinceEpoch} ms',
        tag: 'SyncManager');

    if (saveLogs) await saveToDownloads();
  }

  void completeWithError(String errorMessage) {
    if (completer != null && !completer!.isCompleted) {
      completer!.completeError(errorMessage);
    }

    progress.value = 1.0;
    error = errorMessage;
    status.value = SyncStatus.COMPLETED_ERROR;
    endedAt = DateTime.now().toUtc();
    Logger.error(
        '$name Sync has errored! Elapsed Time: ${endedAt!.millisecondsSinceEpoch - startedAt!.millisecondsSinceEpoch} ms',
        tag: 'SyncManager');
    Logger.error('$name Sync Error: $error', tag: 'SyncManager');

    if (saveLogs) saveToDownloads();
  }

  Future<void> saveToDownloads() async {
    addToOutput("Saving logs to downloads folder...");
    final List<String> text = output.map((e) => e.item2).toList();
    if (text.isNotEmpty) {
      final now = DateTime.now().toLocal();
      String filePath = "/storage/emulated/0/Download/";
      if (kIsDesktop) {
        filePath = (await getDownloadsDirectory())!.path;
      }
      filePath = p.join(
          filePath, "BlueBubbles-sync-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt");
      File file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsString(text.join('\n'));
    }
  }
}
