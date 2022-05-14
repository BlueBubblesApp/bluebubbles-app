import 'dart:convert';

import 'package:bluebubbles/helpers/logger.dart';

class VCard {
  String? _vCardString;
  late List<String> lines;
  String? version;

  VCard(vCardString) {
    _vCardString = vCardString;

    lines = LineSplitter().convert(_vCardString!);
    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].startsWith("BEGIN:VCARD") || lines[i].startsWith("END:VCARD") || lines[i].trim().isEmpty) {
        lines.removeAt(i);
      }
    }

    for (var i = lines.length - 1; i >= 0; i--) {
      if (!lines[i].startsWith(RegExp(r'^\S+(:|;)'))) {
        String tmpLine = lines[i];
        String prevLine = lines[i - 1];
        lines[i - 1] = '$prevLine, $tmpLine';
        lines.removeAt(i);
      }
    }

    version = getWordOfPrefix("VERSION:");
  }

  String? get fullString {
    return _vCardString;
  }

  void printLines() {
    String s;
    Logger.debug('lines #${lines.length}');
    for (var i = 0; i < lines.length; i++) {
      s = i.toString().padLeft(2, '0');
      Logger.debug('$s | ${lines[i]}');
    }
  }

  String getWordOfPrefix(String prefix) {
    //returns a word of a particular prefix from the tokens minus the prefix [case insensitive]
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toUpperCase().startsWith(prefix.toUpperCase())) {
        String word = lines[i];
        word = word.substring(prefix.length, word.length);
        return word;
      }
    }
    return "";
  }

  List<String> getWordsOfPrefix(String prefix) {
    //returns a list of words of a particular prefix from the tokens minus the prefix [case insensitive]
    List<String> result = [];

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toUpperCase().startsWith(prefix.toUpperCase())) {
        String word = lines[i];
        word = word.substring(prefix.length, word.length);
        result.add(word);
      }
    }
    return result;
  }

  String? _strip(String baseString) {
    try {
      return RegExp(r'(?<=:).+').firstMatch(baseString)!.group(0);
    } catch (e) {
      return '';
    }
  }

  List<String> get name {
    String name = getWordOfPrefix("N");
    return _strip(name)!.split(';');
  }

  String? get formattedName {
    String fName = getWordOfPrefix("FN");
    return _strip(fName);
  }

  String? get nickname {
    String nName = getWordOfPrefix("NICKNAME");
    return _strip(nName);
  }

  String? get birthday {
    String bDay = getWordOfPrefix("BDAY");
    return _strip(bDay);
  }

  String? get organisation {
    String org = getWordOfPrefix("ORG");
    return _strip(org);
  }

  String? get title {
    String title = getWordOfPrefix("TITLE");
    return _strip(title);
  }

  String? get position {
    String position = getWordOfPrefix("ROLE");
    return _strip(position);
  }

  String? get categories {
    String categories = getWordOfPrefix("CATEGORIES");
    return _strip(categories);
  }

  String? get gender {
    String gender = getWordOfPrefix('GENDER');
    return _strip(gender);
  }

  String? get note {
    String note = getWordOfPrefix('NOTE');
    return _strip(note);
  }

  @Deprecated("typedTelephone should be used instead")
  String get telephone {
    return getWordOfPrefix("TEL:");
  }

  List<dynamic> get typedTelephone {
    List<String> telephoneTypes = [
      'TEXT',
      'TEXTPHONE',
      'VOICE',
      'VIDEO',
      'CELL',
      'PAGER',
      'FAX',
      'HOME',
      'WORK',
      'OTHER'
    ];
    List<String> telephones;
    List<String> types = [];
    List<dynamic> result = [];
    String? tel = '';

    telephones = getWordsOfPrefix("TEL");

    for (String t in telephones) {
      try {
        if (version == "2.1" || version == "3.0") {
          tel = RegExp(r'(?<=:).+$').firstMatch(t)!.group(0);
        } else if (version == "4.0") {
          tel = RegExp(r'(?<=tel:).+$').firstMatch(t)!.group(0);
        }
      } catch (e) {
        tel = '';
      }
      tel ??= '';

      for (String type in telephoneTypes) {
        if (tel.toUpperCase().contains(type)) {
          types.add(type);
        }
      }

      if (tel.isNotEmpty) {
        result.add([
          tel,
          types,
        ]);
      }
      tel = '';
      types = [];
    }

    return result;
  }

  @Deprecated("typedEmail should be used instead")
  String? get email {
    String email = getWordOfPrefix("EMAIL");
    return _strip(email);
  }

  List<dynamic> get typedEmail => _typedProperty('EMAIL');
  List<dynamic> get typedURL => _typedProperty('URL');

  List<dynamic> _typedProperty(String property) {
    // base function for getting typed EMAIL+URL
    List<String> propertyTypes = [
      'HOME',
      'INTERNET',
      'WORK',
      'OTHER',
    ];
    List<String> matches;
    List<String> types = [];
    List<dynamic> result = [];
    String? res = '';

    matches = getWordsOfPrefix(property);

    for (String match in matches) {
      try {
        res = RegExp(r'(?<=:).+$').firstMatch(match)!.group(0);
      } catch (e) {
        res = '';
      }

      for (String type in propertyTypes) {
        if (match.toUpperCase().contains(type)) {
          types.add(type);
        }
      }

      if (res!.isNotEmpty) {
        if (property == 'ADR') {
          List<String> adress = res.split(';');
          result.add([
            adress,
            types,
          ]);
        } else {
          result.add([
            res,
            types,
          ]);
        }
      }
      res = '';
      types = [];
    }

    return result;
  }

  List<dynamic> get typedAddress {
    List<String> addressTypes = [
      'HOME',
      'WORK',
      'POSTAL',
      'DOM',
    ];
    List<String> addresses;
    List<String> types = [];
    List<dynamic> result = [];
    String? adr = '';

    addresses = getWordsOfPrefix("ADR");

    for (String a in addresses) {
      try {
        if (version == "2.1" || version == "3.0") {
          adr = RegExp(r'(?<=(;|:);).+$').firstMatch(a)!.group(0);
        } else if (version == "4.0") {
          adr = RegExp(r'(?<=LABEL=").+(?=":;)').firstMatch(a)!.group(0);
        }
      } catch (e) {
        adr = '';
      }

      adr ??= '';

      if (adr.startsWith(r';')) {
        //remove leading semicolon
        adr = adr.substring(1);
      }

      for (String type in addressTypes) {
        if (adr.toUpperCase().contains(type)) {
          types.add(type);
        }
      }

      result.add([
        adr.split(';'),
        types
      ]); //Add splitted adress ( home;street;city -> [home, street, city]) along with its type
      adr = '';
      types = [];
    }

    return result; // in this format: [[[adr_1_params], [adr_1_types]], [[adr_2_params], [adr_2_types]]]
  }
}
