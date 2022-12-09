import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

EventDispatcher eventDispatcher = Get.isRegistered<EventDispatcher>() ? Get.find<EventDispatcher>() : Get.put(EventDispatcher());

class EventDispatcher extends GetxService with WidgetsBindingObserver {
  final StreamController<Tuple2<String, dynamic>> _stream = StreamController<Tuple2<String, dynamic>>.broadcast();
  
  Stream<Tuple2<String, dynamic>> get stream => _stream.stream;
  
  @override
  void onClose() {
    _stream.close();
    super.onClose();
  }

  void emit(String type, [dynamic data]) {
    _stream.sink.add(Tuple2(type, data));
  }
}
