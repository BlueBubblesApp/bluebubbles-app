import 'dart:isolate';

import 'package:bluebubbles/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:universal_io/io.dart';

Future<Image?> decodeIsolate(PlatformFile file) async {
  try {
    return decodeImage(file.bytes ?? await File(file.path!).readAsBytes())!;
  } catch (_) {
    return null;
  }
}

void unsupportedToPngIsolate(IsolateData param) {
  try {
    final bytes = param.file.bytes ?? (kIsWeb ? null : File(param.file.path!).readAsBytesSync());
    if (bytes == null) {
      param.sendPort.send(null);
      return;
    }
    final image = decodeImage(bytes)!;
    final encoded = encodePng(image);
    param.sendPort.send(encoded);
  } catch (_) {
    param.sendPort.send(null);
  }
}

class IsolateData {
  final PlatformFile file;
  final SendPort sendPort;

  IsolateData(this.file, this.sendPort);
}