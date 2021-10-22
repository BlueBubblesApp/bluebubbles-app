import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:flutter/cupertino.dart';

/// [TextFieldBloc] holds in memory all of the data for all of the textfields.
///
/// It's purpose is to keep the text in each text field even when you leave a conversation
/// so that when you re-enter, the text will still be there
///
/// This class is a singleton
class TextFieldBloc {
  factory TextFieldBloc() {
    return _textFieldBloc;
  }

  static final TextFieldBloc _textFieldBloc = TextFieldBloc._internal();

  TextFieldBloc._internal();

  final Map<String, TextFieldData> _textFields = {};

  TextFieldData? getTextField(String chatGuid) {
    if (_textFields.containsKey(chatGuid)) {
      return _textFields[chatGuid];
    } else {
      _textFields[chatGuid] = TextFieldData();
      _textFields[chatGuid]!.controller = TextEditingController();
      _textFields[chatGuid]!.subjectController = TextEditingController();
      return _textFields[chatGuid];
    }
  }
}

/// [TextFieldData] holds a TextEditingController and a list of strings that link to attachments
class TextFieldData {
  late TextEditingController controller;
  late TextEditingController subjectController;
  List<PlatformFile> attachments = [];
}
