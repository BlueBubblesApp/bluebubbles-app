import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:convert/convert.dart';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';

class ImageActions {
  static Uint8List? convertToPng(Map<String, dynamic> fileData) {
    try {
      final path = fileData['path'] as String?;
      final bytes = fileData['bytes'] as Uint8List?;

      // Get image bytes from either bytes or file path
      final Uint8List? imageBytes = bytes ?? (path != null && !kIsWeb ? File(path).readAsBytesSync() : null);

      if (imageBytes == null) {
        return null;
      }

      var image = img.decodeImage(imageBytes);
      if (image == null) {
        return null;
      }

      // Bake EXIF orientation into the pixels. `decodeImage` does not apply it,
      // and every consumer of the converted file assumes it is upright — the
      // widget tree deliberately does no orientation correction of its own.
      // `bakeOrientation` also clears the tag, so the result can't be rotated
      // twice by the platform decoder later.
      image = img.bakeOrientation(image);

      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      Logger.warn('Error converting image to PNG: $e');
      return null;
    }
  }

  /// Decodes a multi-resolution `.ico` file and re-encodes its largest frame as
  /// PNG. Flutter's `Image` widget has no ICO decoder — this is why the
  /// preview pipeline used to discard every favicon served as `image/x-icon` —
  /// but the `image` package's own format sniffing already recognises ICO, so
  /// no extra dependency is needed to read it.
  /// Input: Map with 'bytes' key (Uint8List of the raw .ico file)
  /// Output: PNG-encoded bytes of the largest embedded frame, or null on
  /// failure (corrupt file, or a decoder that returns no frames)
  static Uint8List? convertIcoToPng(Map<String, dynamic> input) {
    try {
      final bytes = input['bytes'] as Uint8List;

      // Plenty of sites serve a plain PNG/BMP under `Content-Type: image/x-icon`
      // (Google's favicons among them) — `IcoDecoder` checks the real ICO
      // header's reserved field and returns null on anything else, so a site
      // that mislabels its icon this way used to have it discarded outright.
      // Falling back to generic format sniffing recovers those.
      var decoded = img.decodeIco(bytes);
      decoded ??= img.decodeImage(bytes);
      if (decoded == null) return null;

      // An .ico embeds several resolutions of the same mark; [img.decodeIco]
      // returns them all as one multi-frame Image (frame 0 is whichever the
      // file listed first, not necessarily the largest). Pick the biggest so a
      // favicon does not get stuck at a 16x16 frame when a 256x256 one shipped
      // alongside it.
      final frame = decoded.frames.reduce((a, b) => a.width * a.height >= b.width * b.height ? a : b);

      return Uint8List.fromList(img.encodePng(frame));
    } catch (e) {
      Logger.warn('Error converting ICO to PNG: $e');
      return null;
    }
  }

  /// Reads EXIF data from an image file
  /// Input: Map with 'path' key containing file path
  /// Output: Map<String, String> with EXIF tag names and their printable values
  static Future<Map<String, String>?> readExifData(dynamic input) async {
    try {
      final path = input['path'] as String?;
      if (path == null || kIsWeb) {
        return null;
      }

      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }

      // Read EXIF data
      final exifData = await readExifFromFile(file);

      // Convert IfdTag values to strings for serialization.
      final result = <String, String>{};
      for (var entry in exifData.entries) {
        // Only save certain EXIF tags.
        // There rae encoding issues when storing some into ObjectBox.
        // This filter allows us to keep the most useful tags, that the app will actually use.
        if (!entry.key.contains('Image') && !entry.key.contains('EXIF')) continue;
        result[entry.key] = entry.value.printable.toString();
      }

      return result;
    } catch (e) {
      Logger.warn('Error reading EXIF data: $e');
      return null;
    }
  }

  /// Reads the numeric EXIF orientation tag (1-8, per the EXIF spec) and raw
  /// (pre-rotation) pixel dimensions directly from [path]. Must be called on
  /// the ORIGINAL file, before any format conversion (e.g. HEIC/TIFF -> PNG),
  /// since conversion can drop the EXIF orientation tag entirely.
  /// Input: Map with 'path' key containing file path
  /// Output: Map with 'orientation' (int, defaults to 1), 'width', 'height'
  /// (raw/unswapped, may be null), and 'raw' (the same printable EXIF tag
  /// dump produced by [readExifData], reused here to avoid a second isolate
  /// round trip). Returns null if the file has no readable EXIF at all.
  static Future<Map<String, dynamic>?> readExifOrientation(dynamic input) async {
    try {
      final path = input['path'] as String?;
      if (path == null || kIsWeb) {
        return null;
      }

      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }

      final exifData = await readExifFromFile(file);
      if (exifData.isEmpty) {
        return null;
      }

      final raw = <String, String>{};
      for (var entry in exifData.entries) {
        if (!entry.key.contains('Image') && !entry.key.contains('EXIF')) continue;
        raw[entry.key] = entry.value.printable.toString();
      }

      int orientation = 1;
      final orientationTag = exifData['Image Orientation'];
      if (orientationTag != null) {
        try {
          orientation = orientationTag.values.firstAsInt();
        } catch (_) {
          orientation = 1;
        }
      }

      int? width;
      int? height;
      if (exifData.containsKey('EXIF ExifImageWidth')) {
        width = exifData['EXIF ExifImageWidth']!.values.firstAsInt();
      } else if (exifData.containsKey('Image ImageWidth')) {
        width = exifData['Image ImageWidth']!.values.firstAsInt();
      }
      if (exifData.containsKey('EXIF ExifImageLength')) {
        height = exifData['EXIF ExifImageLength']!.values.firstAsInt();
      } else if (exifData.containsKey('Image ImageLength')) {
        height = exifData['Image ImageLength']!.values.firstAsInt();
      }

      return {'orientation': orientation, 'width': width, 'height': height, 'raw': raw};
    } catch (e) {
      Logger.warn('Error reading EXIF orientation: $e');
      return null;
    }
  }

  /// Generates a downsampled, rotation-corrected JPEG preview for fast inline
  /// display, using the `image` package. Not usable for HEIC sources (the
  /// `image` package can't decode HEIC) -- callers should use
  /// `flutter_image_compress` directly for those.
  /// Input: Map with 'path' (source file), 'outputPath' (destination),
  /// 'maxDimension' (int, longest-side cap), 'quality' (int, 0-100)
  /// Output: true on success, false on failure (never throws)
  static Future<bool> generatePreview(dynamic input) async {
    try {
      final path = input['path'] as String;
      final outputPath = input['outputPath'] as String;
      final maxDimension = input['maxDimension'] as int;
      final quality = input['quality'] as int;

      final bytes = await File(path).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return false;

      // Bakes rotation from the decoded image's own EXIF orientation (if
      // present) into the pixel buffer. This is safe here because the
      // preview is a derived cache artifact, not the source of truth --
      // the original file's bytes are never touched.
      image = img.bakeOrientation(image);

      final longestSide = image.width > image.height ? image.width : image.height;
      if (longestSide > maxDimension) {
        // copyResize defaults to Interpolation.nearest, which aliases badly
        // going from ~4000px down to ~1080px -- previews come out crunchy.
        image = image.width >= image.height
            ? img.copyResize(image, width: maxDimension, interpolation: img.Interpolation.average)
            : img.copyResize(image, height: maxDimension, interpolation: img.Interpolation.average);
      }

      final encoded = img.encodeJpg(image, quality: quality);
      await File(outputPath).writeAsBytes(encoded);
      return true;
    } catch (e) {
      Logger.warn('Error generating image preview: $e');
      return false;
    }
  }

  /// Reads GIF dimensions from a file without loading entire file into memory
  /// Input: Map with 'path' key containing file path
  /// Output: Map with 'width' and 'height' keys
  static Future<Map<String, int>?> getGifDimensions(dynamic input) async {
    try {
      final path = input['path'] as String?;
      if (path == null || kIsWeb) {
        return null;
      }

      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }

      // Only read the first 10 bytes needed for GIF dimensions
      final bytes = await file.openRead(0, 10).first;

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

      return {'width': width, 'height': height};
    } catch (e) {
      Logger.warn('Error reading GIF dimensions: $e');
      return null;
    }
  }
}
