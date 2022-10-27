import 'package:bluebubbles/models/models.dart';

class ChatMessages {
  final Map<String, Message> _messages = {};
  final Map<String, Message> _reactions = {};
  final Map<String, Map<String, Message>> _threads = {};
  final Map<String, Map<String, Message>> _edits = {};

  bool get isEmpty => _messages.isEmpty;
  bool get isNotEmpty => _messages.isNotEmpty;
  List<Message> get messages => _messages.values.toList();
  List<Message> get reactions => _reactions.values.toList();
  List<Message> threads(String originatorGuid) => _threads[originatorGuid]?.values.toList() ?? [];

  void addMessages(List<Message> __messages) {
    for (Message m in __messages) {
      if (m.associatedMessageGuid != null) {
        // add reactions
        _reactions[m.guid!] = m;
      } else {
        // add regular texts
        _messages[m.guid!] = m;
      }
      if (m.threadOriginatorGuid != null && !m.guid!.startsWith("temp")) {
        // add threaded messages
        _threads[m.threadOriginatorGuid!] ??= {};
        _threads[m.threadOriginatorGuid]![m.guid!] = m;
      }
      if (_threads.keys.contains(m.guid)) {
        // add thread 'originator'
        _threads[m.guid]![m.guid!] = m;
      }
    }
  }

  void addThreadOriginator(Message m) {
    _threads[m.guid!] ??= {};
    _threads[m.guid]![m.guid!] = m;
  }

  Message? getMessage(String guid) {
    return _messages[guid] ?? _reactions[guid];
  }

  // It isn't guaranteed that the thread originator will be in the regular
  // messages list, in case it is much older than the currently loaded messages.
  // Prefer to use this method to find originator.
  Message? getThreadOriginator(String guid) {
    return _threads[guid]?[guid];
  }
}