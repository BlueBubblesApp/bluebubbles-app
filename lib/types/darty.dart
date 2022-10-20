import 'package:bluebubbles/helpers/constants.dart';
import 'package:flutter/foundation.dart';

extension UrlParsing on String {
  bool get hasUrl => urlRegex.hasMatch(this) && !kIsWeb;
}

enum MessageError { NO_ERROR, TIMEOUT, NO_CONNECTION, BAD_REQUEST, SERVER_ERROR }

extension MessageErrorExtension on MessageError {
  static const codes = {
    MessageError.NO_ERROR: 0,
    MessageError.TIMEOUT: 4,
    MessageError.NO_CONNECTION: 1000,
    MessageError.BAD_REQUEST: 1001,
    MessageError.SERVER_ERROR: 1002,
  };

  int get code => codes[this]!;
}
