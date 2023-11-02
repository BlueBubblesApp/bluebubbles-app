import 'package:bluebubbles/core/abstractions/network/attachment_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/chat_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/contact_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/facetime_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/fcm_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/findmy_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/firebase_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/handle_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/message_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/scheduled_messages_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/server_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/settings_network_service.dart';
import 'package:bluebubbles/core/abstractions/network/theme_network_service.dart';
import 'package:bluebubbles/core/services/services.dart' as services;

import '../service.dart';


abstract class NetworkService extends Service {
  @override
  bool required = true;

  @override
  List<Service> dependencies = [services.settings];
  
  ServerNetworkService get server;
  AttachmentNetworkService get attachments;
  MessageNetworkService get messages;
  ChatNetworkService get chats;
  HandleNetworkService get handles;
  FcmNetworkService get fcm;
  ContactNetworkService get contacts;
  FaceTimeNetworkService get facetime;
  FindMyNetworkService get findmy;
  FirebaseNetworkService get firebase;
  ScheduledMessagesNetworkService get scheduled;
  SettingsNetworkService get settings;
  ThemeNetworkService get themes;
  
  void testApi();
}

abstract class SubNetworkService {
  // Nothing is here, but allows us to add stuff later, if required
}