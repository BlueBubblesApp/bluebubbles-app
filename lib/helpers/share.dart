import 'package:flutter/services.dart';

class Share {
  static const MethodChannel _channel =
      const MethodChannel('com.bluebubbles.messaging');

  /// Share a file with other apps.
  static Future<void> file(
      String subject, String filename, String filepath, String mimeType) async {
    Map<String, dynamic> argsMap = Map<String, dynamic>();

    argsMap.addAll({
      'subject': '$subject',
      'filename': '$filename',
      'filepath': '$filepath',
      'mimeType': '$mimeType'
    });
    await _channel.invokeMethod('share-file', argsMap);
  }
}
