import 'package:async_task/async_task.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/task_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

bool isNullOrEmpty(dynamic input) {
  if (input == null) return true;
  if (input is String) {
    input = input.trim();
  }
  return GetUtils.isNullOrBlank(input) ?? false;
}

bool isNullOrZero(dynamic input) {
  if (input == null) return true;
  if (input == 0) return true;
  if (input == 0.0) return true;
  return false;
}

Map<String, dynamic> mergeTopLevelDicts(Map<String, dynamic>? d1, Map<String, dynamic>? d2) {
  if (d1 == null && d2 == null) return {};
  if (d1 == null && d2 != null) return d2;
  if (d1 != null && d2 == null) return d1;

  // Update metadata
  for (var i in d2!.entries) {
    if (d1!.containsKey(i.key)) continue;
    d1[i.key] = i.value;
  }

  return d1!;
}

/// Create a "fake" asynchronous task from a traditionally synchronous task
///
/// Used for heavy ObjectBox read/writes to avoid causing jank
Future<T?> createAsyncTask<T>(AsyncTask<List<dynamic>, T> task) async {
  final executor = AsyncExecutor(parallelism: 0, taskTypeRegister: () => [task], logger: asyncTaskLogger);
  executor.logger.enabled = true;
  executor.logger.enabledExecution = true;
  await executor.execute(task);
  return task.result;
}

bool get kIsDesktop => (Platform.isWindows || Platform.isLinux || Platform.isMacOS) && !kIsWeb;

bool get isSnap => !kIsWeb && Platform.isLinux && Platform.environment.containsKey('SNAP');

bool get isFlatpak => !kIsWeb && Platform.isLinux && Platform.environment.containsKey('FLATPAK_ID');

bool get isMsix => !kIsWeb && Platform.isWindows && Platform.resolvedExecutable.contains('WindowsApps');

bool get isStoreMsix => isMsix && Platform.resolvedExecutable.contains(r'\23344BlueBubbles.BlueBubbles_');

bool get isSideloadMsix => isMsix && !isStoreMsix;

String get appVersion {
  final info = FilesystemSvc.packageInfo;
  final code = info.buildNumber;
  final build = Platform.isAndroid ? "+${code.length > 4 ? code.substring(code.length - 4) : code}" : "";
  final distribution = isSnap
      ? "_Snap"
      : isFlatpak
          ? "_Flatpak"
          : isStoreMsix
              ? "_Msix_Store"
              : isSideloadMsix
                  ? "_Msix_Sideload"
                  : "";
  return "${info.version}${build}_${Platform.operatingSystem.capitalizeFirst!}$distribution";
}

/// From https://github.com/modulovalue/dart_intersperse/blob/master/lib/src/intersperse.dart
Iterable<T> intersperse<T>(T element, Iterable<T> iterable) sync* {
  final iterator = iterable.iterator;
  if (iterator.moveNext()) {
    yield iterator.current;
    while (iterator.moveNext()) {
      yield element;
      yield iterator.current;
    }
  }
}

/// `m:ss`, or `h:mm:ss` from an hour up.
String prettyDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
}
