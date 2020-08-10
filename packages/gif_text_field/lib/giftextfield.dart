import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef void TextViewCreatedCallback(GifTextFieldController controller);

class GifTextField extends StatefulWidget {
  const GifTextField({
    Key key,
    this.onTextViewCreated,
  }) : super(key: key);

  final TextViewCreatedCallback onTextViewCreated;

  @override
  State<StatefulWidget> createState() => _GifTextFieldState();
}

class _GifTextFieldState extends State<GifTextField> {
  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'giftextfield',
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }

  void _onPlatformViewCreated(int id) {
    if (widget.onTextViewCreated == null) {
      return;
    }
    widget.onTextViewCreated(new GifTextFieldController._(id));
  }
}

class GifTextFieldController {
  GifTextFieldController._(int id)
      : _channel = new MethodChannel('giftextfield_$id');

  final MethodChannel _channel;

  Future<void> setText(String text) async {
    assert(text != null);
    return _channel.invokeMethod('setText', text);
  }
}
