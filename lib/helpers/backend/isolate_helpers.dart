import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/services/network/http_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter_isolate/flutter_isolate.dart';

Future<T> runBackgroundTask<T>(void Function(List<Object?>) function) async {
  final completer = Completer<T>();
  final port = RawReceivePort();
  port.handler = (T response) {
    completer.complete(response);
  };

  try {
    FlutterIsolate isolate = await FlutterIsolate.spawn(function, [port.sendPort, http.originOverride]);
    await completer.future;
    isolate.kill();
  } catch (e, stack) {
    Logger.error('An error occurred opening an isolate!', error: e, trace: stack);
  } finally {
    port.close();
  }

  return completer.future;
}