import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/image_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';

class ImageInterface {
  static Future<Uint8List?> convertToPng(PlatformFile file) async {
    final fileData = {'name': file.name, 'path': file.path, 'bytes': file.bytes, 'size': file.size};

    if (isIsolate) {
      return ImageActions.convertToPng(fileData);
    } else {
      return await GetIt.I<GlobalIsolate>().send<Uint8List?>(IsolateRequestType.convertImageToPng, input: fileData);
    }
  }

  /// Reads EXIF data from an image file in the global isolate
  /// Returns a map of EXIF tag names to their string values
  static Future<Map<String, String>?> readExifData(String filePath) async {
    final input = {'path': filePath};

    if (isIsolate) {
      return await ImageActions.readExifData(input);
    } else {
      return await GetIt.I<GlobalIsolate>().send<Map<String, String>?>(IsolateRequestType.readExifData, input: input);
    }
  }

  /// Reads GIF dimensions from a file in the global isolate
  /// Returns a map with 'width' and 'height' keys
  static Future<Map<String, int>?> getGifDimensions(String filePath) async {
    final input = {'path': filePath};

    if (isIsolate) {
      return await ImageActions.getGifDimensions(input);
    } else {
      return await GetIt.I<GlobalIsolate>().send<Map<String, int>?>(IsolateRequestType.getGifDimensions, input: input);
    }
  }

  /// Reads the numeric EXIF orientation (1-8) and raw pixel dimensions from
  /// the ORIGINAL file (call before any format conversion).
  /// Returns a map with 'orientation', 'width', 'height', 'raw' keys.
  static Future<Map<String, dynamic>?> readExifOrientation(String filePath) async {
    final input = {'path': filePath};

    if (isIsolate) {
      return await ImageActions.readExifOrientation(input);
    } else {
      return await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>?>(
        IsolateRequestType.readExifOrientation,
        input: input,
      );
    }
  }

  /// Generates a downsampled, rotation-corrected JPEG preview at [outputPath]
  /// for fast inline display. Not usable for HEIC sources.
  /// Returns true on success.
  static Future<bool> generatePreview({
    required String path,
    required String outputPath,
    required int maxDimension,
    required int quality,
  }) async {
    final input = {'path': path, 'outputPath': outputPath, 'maxDimension': maxDimension, 'quality': quality};

    if (isIsolate) {
      return await ImageActions.generatePreview(input);
    } else {
      return await GetIt.I<GlobalIsolate>().send<bool>(IsolateRequestType.generatePreview, input: input);
    }
  }
}
