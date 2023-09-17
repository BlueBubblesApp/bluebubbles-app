

import 'package:bluebubbles/services/rustpush/rustpush_socket_service.dart';
import 'package:get/get.dart';
import 'socket_io_socket_service.dart';

SocketService socket = Get.isRegistered<SocketService>() ? Get.find<SocketService>() : Get.put(RustPushSocketService());

enum SocketState {
  connected,
  disconnected,
  error,
  connecting,
}

abstract class SocketService {
  Rx<SocketState> state;
  void startedTyping(String chatGuid);
  void stoppedTyping(String chatGuid);
  void updateTypingStatus(String chatGuid);
  void disconnect();
  void reconnect();
  void restartSocket();
  void forgetConnection();

  SocketService(this.state);
}

