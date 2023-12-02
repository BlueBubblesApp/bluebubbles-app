import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:convert/convert.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

String getSizeString(double size) {
  int kb = 1000;
  if (size < kb) {
    return "${(size).floor()} KB";
  } else if (size < pow(kb, 2)) {
    return "${(size / kb).toStringAsFixed(1)} MB";
  } else {
    return "${(size / (pow(kb, 2))).toStringAsFixed(1)} GB";
  }
}

Future<ByteData> loadAsset(String path) {
  return rootBundle.load(path);
}

Size getGifDimensions(Uint8List bytes) {
  String hexString = "";
  // Bytes 6 and 7 are the width bytes of a gif
  hexString += hex.encode(bytes.sublist(7, 8));
  hexString += hex.encode(bytes.sublist(6, 7));
  int width = int.parse(hexString, radix: 16);

  hexString = "";
  // Bytes 8 and 9 are the height bytes of a gif
  hexString += hex.encode(bytes.sublist(9, 10));
  hexString += hex.encode(bytes.sublist(8, 9));
  int height = int.parse(hexString, radix: 16);

  Logger.debug("GIF width: $width");
  Logger.debug("GIF height: $height");
  Size size = Size(width.toDouble(), height.toDouble());
  return size;
}

String getFilenameFromUri(String url) => url.split("/").last.split("?").first;

Future<File?> saveImageFromUrl(String guid, String url) async {
  // Make sure the URL is "formed"
  if (kIsWeb || !url.contains("/")) return null;
  final filename = getFilenameFromUri(url);

  try {
    final response = await http.dio.get(url, options: Options(responseType: ResponseType.bytes, headers: http.headers));

    Directory baseDir = Directory("${Attachment.baseDirectory}/$guid");
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    String newPath = "${baseDir.path}/$filename";
    File file = File(newPath);
    await file.writeAsBytes(response.data);

    return file;
  } catch (ex) {
    return null;
  }
}