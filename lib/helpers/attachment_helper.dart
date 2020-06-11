import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:vcard_parser/vcard_parser.dart';

class AttachmentHelper {
  static String createAppleLocation(double longitude, double latitude,
      {iosVersion = "10.2"}) {
    List<String> lines = [
      "BEING:VCARD",
      "VERSION:2.0",
      "PRODID:-//Apple Inc.//iOS $iosVersion//EN",
      "N:;Current Location;;;",
      "FN:Current Location",
      "item1.URL;type=pref:http://maps.apple.com/?ll=$longitude\,$latitude&q=$longitude\,$latitude",
      "item1.X-ABLabel:map url",
      "END:VCARD"
    ];

    return lines.join("\n");
  }

  static Map<String, double> parseAppleLocation(String appleLocation) {
    // Map<String, dynamic> map = VcardParser(appleLocation).parse();
    List<String> lines = appleLocation.split("\n");
    String url = lines[5];
    String query = url.split("&q=")[1];

    return {
      "longitude": double.tryParse((query.split("\\,")[0])),
      "latitude": double.tryParse(query.split("\\,")[1])
    };
  }

  static Contact parseAppleContact(String appleContact) {
    Map<String, dynamic> _contact = VcardParser(appleContact).parse();
    debugPrint(_contact.toString());

    //{BEGIN: VCARD, VERSION: 3.0, PRODID: -//Apple Inc.//iPhone OS 11.0.2//EN, N: Shihabi; Brandon;, FN: Brandon  Shihabi, EMAIL;type=INTERNET;type=HOME;type=pref: {name: pref, value: brandon.shihabi@gmail.com}, EMAIL;type=INTERNET;type=WORK: {name: WORK, value: shihabib22@student.jhs.net}, TEL;type=IPHONE;type=CELL;type=VOICE;type=pref: {name: pref, value: +19167167312}, END: VCARD}
    Contact contact = Contact();
    if (_contact.containsKey("N")) {
      String firstName = (_contact["N"] + " ").split(";")[1];
      String lastName = _contact["N"].split(";")[0];
      contact.displayName = firstName + " " + lastName;
    } else if (_contact.containsKey("FN")) {
      contact.displayName = _contact["FN"];
    }
    List<Item> emails = <Item>[];
    List<Item> phones = <Item>[];
    _contact.keys.forEach((String key) {
      if (key.contains("EMAIL")) {
        String label = key.split("type=")[2].replaceAll(";", "");
        emails.add(
          Item(
            value: (_contact[key] as Map<String, dynamic>)["value"],
            label: label,
          ),
        );
      } else if (key.contains("TEL")) {
        phones.add(
          Item(
            label: "HOME",
            value: (_contact[key] as Map<String, dynamic>)["value"],
          ),
        );
      }
    });
    contact.emails = emails;
    contact.phones = phones;

    return contact;
    // return ;
  }
}
