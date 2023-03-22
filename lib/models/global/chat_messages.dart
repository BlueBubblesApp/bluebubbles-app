import 'package:bluebubbles/models/models.dart';

class ChatMessages {
  final Map<String, Message> _messages = {};
  final Map<String, Message> _reactions = {};
  final Map<String, Attachment> _attachments = {};
  final Map<String, Map<String, Message>> _threads = {};
  final Map<String, Map<String, Message>> _edits = {};

  bool get isEmpty => _messages.isEmpty;
  bool get isNotEmpty => _messages.isNotEmpty;
  List<Message> get messages => _messages.values.toList();
  List<Message> get reactions => _reactions.values.toList();
  List<Attachment> get attachments => _attachments.values.toList();
  List<Message> threads(String originatorGuid, int originatorPart, {bool returnOriginator = true}) =>
      _threads[originatorGuid]?.values.where((e) =>
      (e.normalizedThreadPart == originatorPart && e.guid != originatorGuid) || (returnOriginator ? e.guid == originatorGuid : false)).toList() ?? [];

  void addMessages(List<Message> __messages) {
    for (Message m in __messages) {
      if (m.associatedMessageGuid != null) {
        // add reactions
        _reactions[m.guid!] = m;
      } else {
        // add regular texts
        _messages[m.guid!] = m;
      }
      if (m.threadOriginatorGuid != null && !m.guid!.startsWith("temp") && m.associatedMessageGuid == null) {
        // add threaded messages
        _threads[m.threadOriginatorGuid!] ??= {};
        _threads[m.threadOriginatorGuid]![m.guid!] = m;
      }
      if (_threads.keys.contains(m.guid)) {
        // add thread 'originator'
        _threads[m.guid]![m.guid!] = m;
      }
      _attachments.addEntries(m.attachments.map((e) => MapEntry(e!.guid!, e)));
    }
  }

  void removeMessage(String guid) {
    _messages.remove(guid);
    _reactions.remove(guid);
    final result = _threads.remove(guid);
    if (result == null) {
      for (Map element in _threads.values) {
        element.remove(guid);
      }
    }
    final result2 = _edits.remove(guid);
    if (result2 == null) {
      for (Map element in _edits.values) {
        element.remove(guid);
      }
    }
  }

  void removeAttachments(Iterable<String> guids) {
    for (String s in guids) {
      _attachments.remove(s);
    }
  }

  void addThreadOriginator(Message m) {
    _threads[m.guid!] ??= {};
    _threads[m.guid]![m.guid!] = m;
  }

  Message? getMessage(String guid) {
    return _messages[guid] ?? _reactions[guid];
  }

  Attachment? getAttachment(String guid) {
    return _attachments[guid];
  }

  // It isn't guaranteed that the thread originator will be in the regular
  // messages list, in case it is much older than the currently loaded messages.
  // Prefer to use this method to find originator.
  Message? getThreadOriginator(String guid) {
    final fromOriginatorList = _threads[guid]?[guid];
    if (fromOriginatorList == null) {
      final message = getMessage(guid);
      if (message != null) addThreadOriginator(message);
      return message;
    } else {
      return fromOriginatorList;
    }
  }

  Message? getPreviousReply(String threadGuid, int threadPart, String messageGuid) {
    final thread = threads(threadGuid, threadPart)..sort((a, b) => a.dateCreated!.compareTo(b.dateCreated!));
    final index = thread.indexWhere((element) => element.guid == messageGuid);
    if (index > 0) {
      return thread[index - 1];
    }
    return null;
  }
}