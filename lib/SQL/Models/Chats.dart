import 'package:bluebubble_messages/SQL/Repositories/DatabaseCreator.dart';
import 'package:bluebubble_messages/SQL/Repositories/RepoService.dart';
import 'package:contacts_service/contacts_service.dart';

import '../../singleton.dart';

class Chat {
  String guid;
  String title;
  int lastMessageTimeStamp;
  String chatIdentifier;

  Chat(Map data) {
    this.guid = data["guid"];
    this.lastMessageTimeStamp = data["lastMessageTimeStamp"];
    this.chatIdentifier = data["chatIdentifier"];
    this.title = "";
    if (data == null || data["displayName"] == "") {
      this.title = "";
      for (int i = 0; i < data["participants"].length; i++) {
        var participant = data["participants"][i];
        // _title += (participant["id"] + ", ").toString();
        this.title += _convertNumberToContact(participant["id"]) + ", ";
        RepositoryServiceChats.addChat(this);
      }
    } else {
      this.title = data["displayName"];
    }
  }

  String _convertNumberToContact(String id) {
    if (Singleton().contacts == null) return id;
    String contactTitle = id;
    Singleton().contacts.forEach((Contact contact) {
      contact.phones.forEach((Item item) {
        String formattedNumber = item.value.replaceAll(RegExp(r'[-() ]'), '');
        if (formattedNumber == id || "+1" + formattedNumber == id) {
          contactTitle = contact.displayName;
          return contactTitle;
        }
      });
      contact.emails.forEach((Item item) {
        if (item.value == id) {
          contactTitle = contact.displayName;
          return contactTitle;
        }
      });
    });
    return contactTitle;
  }

  Chat.fromJson(Map<String, dynamic> json) {
    this.guid = json["guid"];
    this.title = json["title"];
    this.lastMessageTimeStamp = json["lastMessageTimeStamp"];
    this.chatIdentifier = json["chatIdentifier"];
  }
}
