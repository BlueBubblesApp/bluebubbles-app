import 'package:bluebubble_messages/SQL/Repositories/DatabaseCreator.dart';

class Chat {
  String guid;
  String title;
  int lastMessageTimeStamp;
  String chatIdentifier;

  Chat(this.guid, this.title, this.lastMessageTimeStamp, this.chatIdentifier);

  Chat.fromJson(Map<String, dynamic> json) {
    this.guid = json["guid"];
    this.title = json["title"];
    this.lastMessageTimeStamp = json["lastMessageTimeStamp"];
    this.chatIdentifier = json["chatIdentifier"];
  }
}
