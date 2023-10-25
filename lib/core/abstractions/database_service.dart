import 'dart:async';

import 'package:bluebubbles/models/models.dart';
import '../abstractions/service.dart';


abstract class DatabaseService extends Service {
  // Messages
  Box<Attachment> get attachments;
  Box<Message> get messages;
  Box<Handle> get handles;
  Box<Chat> get chats;
  Box<Contact> get contacts;

  // Firebase
  Box<FCMData> get fcm;

  // Scheduled Messages
  Box<ScheduledMessage> get scheduledMessages;

  // Themes
  Box<ThemeStruct> get themes;
  Box<ThemeEntry> get themeEntries;

  
  // ignore: deprecated_member_use_from_same_package
  Box<ThemeObject> get themeObjects;

  @override
  bool required = true;

  @override
  Future<void> start() async {
    await seed();
  }

  Future<void> seed();

  Future<void> purge({ onlyMessageData = false });

  R runInTransaction<R>(TxMode mode, R Function() fn) {
    throw UnimplementedError("runInTransaction() is not implemented");
  }
}