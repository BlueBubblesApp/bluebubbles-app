import 'package:async_task/async_task.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  final executor = AsyncExecutor(parallelism: 0, taskTypeRegister: () => [task]);
  executor.logger.enabled = true;
  executor.logger.enabledExecution = true;
  await executor.execute(task);
  return task.result;
}

bool get kIsDesktop => (Platform.isWindows || Platform.isLinux || Platform.isMacOS) && !kIsWeb;

bool get isSnap => !kIsWeb && Platform.isLinux && Platform.environment['SNAP'] != null;

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

String prettyDuration(Duration duration) {
  var components = <String>[];

  var days = duration.inDays;
  if (days != 0) {
    components.add('$days:');
  }
  var hours = duration.inHours % 24;
  if (hours != 0) {
    components.add('${hours < 10 ? '0' : ''}$hours:');
  }
  var minutes = duration.inMinutes % 60;
  if (minutes != 0) {
    components.add('${minutes < 10 ? '0' : ''}$minutes:');
  }

  var seconds = duration.inSeconds % 60;
  if (components.isEmpty || seconds != 0) {
    if (components.isEmpty) {
      components.add('00:');
    }
    components.add('${seconds < 10 ? '0' : ''}$seconds');
  }
  var joined = components.join();
  if (joined.characters.first == '0') {
    return joined.substring(1);
  } else {
    return joined;
  }
}