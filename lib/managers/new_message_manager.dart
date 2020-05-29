class NewMessageManager {
  factory NewMessageManager() {
    return _manager;
  }

  static final NewMessageManager _manager = NewMessageManager._internal();

  NewMessageManager._internal();
}
