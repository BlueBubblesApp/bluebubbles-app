import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:convert/convert.dart';
import 'package:flutter/services.dart';

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

  Logger.debug("Decoded GIF width: $width");
  Logger.debug("Decoded GIF height: $height");
  Size size = Size(width.toDouble(), height.toDouble());
  return size;
}
