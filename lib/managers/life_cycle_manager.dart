import 'package:bluebubble_messages/socket_manager.dart';

class LifeCycleManager {
  factory LifeCycleManager() {
    return _manager;
  }

  static final LifeCycleManager _manager = LifeCycleManager._internal();

  LifeCycleManager._internal();

  bool _isAlive = false;

  bool get isAlive => _isAlive;

  startDownloader() {
    opened();
  }

  finishDownloader() {
    if (!_isAlive &&
        SocketManager().attachmentDownloaders.length == 0 &&
        SocketManager().attachmentSenders.length == 0) {
      close();
    }
  }

  opened() {
    _isAlive = true;
    if (SocketManager().socket == null) SocketManager().startSocketIO();
  }

  close() {
    _isAlive = false;
    if (SocketManager().attachmentDownloaders.length == 0 &&
        SocketManager().attachmentSenders.length == 0) {
      SocketManager().closeSocket();
    }
  }
}
