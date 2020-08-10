import 'package:flutter/cupertino.dart';

class TextFieldBloc {
  factory TextFieldBloc() {
    return _chatBloc;
  }

  static final TextFieldBloc _chatBloc = TextFieldBloc._internal();

  TextFieldBloc._internal();

  Map<String, TextEditingController> _textFields = new Map();

  TextEditingController getTextField(String chatGuid) {
    if (_textFields.containsKey(chatGuid)) {
      return _textFields[chatGuid];
    } else {
      _textFields[chatGuid] = new TextEditingController();
      return _textFields[chatGuid];
    }
  }
}
