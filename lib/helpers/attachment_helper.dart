import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:vcard_parser/vcard_parser.dart';

class AttachmentHelper {
  static String createAppleLocation(double longitude, double latitude,
      {iosVersion = "13.4.1"}) {
    List<String> lines = [
      "BEGIN:VCARD",
      "VERSION:3.0",
      "PRODID:-//Apple Inc.//iPhone OS $iosVersion//EN",
      "N:;Current Location;;;",
      "FN:Current Location",
      "item1.URL;type=pref:http://maps.apple.com/?ll=$longitude\\,$latitude&q=$longitude\\,$latitude",
      "item1.X-ABLabel:map url",
      "END:VCARD"
      ""
    ];

    return lines.join("\n");
  }

  static Map<String, double> parseAppleLocation(String appleLocation) {
    List<String> lines = appleLocation.split("\n");
    String url = lines[5];
    String query = url.split("&q=")[1];

    if (query.contains("\\")) {
      return {
        "longitude": double.tryParse((query.split("\\,")[0])),
        "latitude": double.tryParse(query.split("\\,")[1])
      };
    } else {
      return {
        "longitude": double.tryParse((query.split(",")[0])),
        "latitude": double.tryParse(query.split(",")[1])
      };
    }
  }

  static Contact parseAppleContact(String appleContact) {
    Map<String, dynamic> _contact = VcardParser(appleContact).parse();
    debugPrint(_contact.toString());

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
