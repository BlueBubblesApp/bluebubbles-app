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
        lines[i - 1] = prevLine + ', ' + tmpLine;
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
    String _name = getWordOfPrefix("N");
    return _strip(_name)!.split(';');
  }

  String? get formattedName {
    String _fName = getWordOfPrefix("FN");
    return _strip(_fName);
  }

  String? get nickname {
    String _nName = getWordOfPrefix("NICKNAME");
    return _strip(_nName);
  }

  String? get birthday {
    String _bDay = getWordOfPrefix("BDAY");
    return _strip(_bDay);
  }

  String? get organisation {
    String _org = getWordOfPrefix("ORG");
    return _strip(_org);
  }

  String? get title {
    String _title = getWordOfPrefix("TITLE");
    return _strip(_title);
  }

  String? get position {
    String _position = getWordOfPrefix("ROLE");
    return _strip(_position);
  }

  String? get categories {
    String _categories = getWordOfPrefix("CATEGORIES");
    return _strip(_categories);
  }

  String? get gender {
    String _gender = getWordOfPrefix('GENDER');
    return _strip(_gender);
  }

  String? get note {
    String _note = getWordOfPrefix('NOTE');
    return _strip(_note);
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
    String? _tel = '';

    telephones = getWordsOfPrefix("TEL");

    for (String tel in telephones) {
      try {
        if (version == "2.1" || version == "3.0") {
          _tel = RegExp(r'(?<=:).+$').firstMatch(tel)!.group(0);
        } else if (version == "4.0") {
          _tel = RegExp(r'(?<=tel:).+$').firstMatch(tel)!.group(0);
        }
      } catch (e) {
        _tel = '';
      }

      for (String type in telephoneTypes) {
        if (tel.toUpperCase().contains(type)) {
          types.add(type);
        }
      }

      if (_tel!.isNotEmpty) {
        result.add([
          _tel,
          types,
        ]);
      }
      _tel = '';
      types = [];
    }

    return result;
  }

  @Deprecated("typedEmail should be used instead")
  String? get email {
    String _email = getWordOfPrefix("EMAIL");
    return _strip(_email);
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
    String? _res = '';

    matches = getWordsOfPrefix(property);

    for (String match in matches) {
      try {
        _res = RegExp(r'(?<=:).+$').firstMatch(match)!.group(0);
      } catch (e) {
        _res = '';
      }

      for (String type in propertyTypes) {
        if (match.toUpperCase().contains(type)) {
          types.add(type);
        }
      }

      if (_res!.isNotEmpty) {
        if (property == 'ADR') {
          List<String> adress = _res.split(';');
          result.add([
            adress,
            types,
          ]);
        } else {
          result.add([
            _res,
            types,
          ]);
        }
      }
      _res = '';
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
    String? _adr = '';

    addresses = getWordsOfPrefix("ADR");

    for (String adr in addresses) {
      try {
        if (version == "2.1" || version == "3.0") {
          _adr = RegExp(r'(?<=(;|:);).+$').firstMatch(adr)!.group(0);
        } else if (version == "4.0") {
          _adr = RegExp(r'(?<=LABEL=").+(?=":;)').firstMatch(adr)!.group(0);
        }
      } catch (e) {
        _adr = '';
      }

      if (_adr!.startsWith(r';')) {
        //remove leading semicolon
        _adr = _adr.substring(1);
      }

      for (String type in addressTypes) {
        if (adr.toUpperCase().contains(type)) {
          types.add(type);
        }
      }

      result.add([
        _adr.split(';'),
        types
      ]); //Add splitted adress ( home;street;city -> [home, street, city]) along with its type
      _adr = '';
      types = [];
    }

    return result; // in this format: [[[adr_1_params], [adr_1_types]], [[adr_2_params], [adr_2_types]]]
  }
}
