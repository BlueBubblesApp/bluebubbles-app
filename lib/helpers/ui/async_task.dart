import 'dart:async';

import 'package:flutter/scheduler.dart';

Future<T> runAsync<T>(T Function() function) async {
  return await SchedulerBinding.instance.scheduleTask(() {
    return function.call();
  }, Priority.animation);
}