import 'dart:convert';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/image_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;
import 'package:path/path.dart';
import 'package:bluebubbles/models/models.dart' show AttachmentUploadProgress;
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vcf_dart/vcf_dart.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ignore: non_constant_identifier_names
AttachmentsService AttachmentsSvc =
    Get.isRegistered<AttachmentsService>() ? Get.find<AttachmentsService>() : Get.put(AttachmentsService());

/// Wrapper class for attachments being sent that includes both the file and send progress
class AttachmentWithProgress {
  final PlatformFile file;
  final AttachmentUploadProgress progress;

  AttachmentWithProgress(this.file, this.progress);
}

class AttachmentsService extends GetxService {
  dynamic getContent(Attachment attachment, {String? path, bool? autoDownload, Function(PlatformFile)? onComplete}) {
    if (attachment.guid?.startsWith("temp") ?? false) {
      final sendProgress = OutgoingMsgHandler.attachmentProgress.firstWhereOrNull((e) => e.guid == attachment.guid);
      if (sendProgress != null) {
        // Check if we can also get the file to display behind the progress
        if (!kIsWeb) {
          final pathName = path ?? attachment.path;
          if (File(pathName).existsSync()) {
            final file = PlatformFile(
              name: attachment.transferName!,
              path: pathName,
              size: attachment.totalBytes ?? 0,
            );
            // Return both the file and progress so UI can show image with progress overlay
            return AttachmentWithProgress(file, sendProgress);
          }
        }
        // If we can't get the file, just return the progress
        return sendProgress;
      } else {
        // Check if the temp attachment file was saved locally before send
        // This handles the case where an attachment is being prepared for send
        if (!kIsWeb) {
          final pathName = path ?? attachment.path;
          if (File(pathName).existsSync()) {
            // File exists at the temp path, return it
            return PlatformFile(
              name: attachment.transferName!,
              path: pathName,
              size: attachment.totalBytes ?? 0,
            );
          }

          // If file doesn't exist at temp path, it may have been replaced with a real GUID
          // Try to find the updated attachment from the message
          // This is a fallback for when the UI still references the old temp attachment object
          if (attachment.message.target != null) {
            try {
              final message = attachment.message.target!;
              final messageAttachments = message.dbAttachments;
              final match = messageAttachments.firstWhereOrNull((a) =>
                  !a.guid!.startsWith("temp") &&
                  a.transferName == attachment.transferName &&
                  a.totalBytes == attachment.totalBytes);

              if (match != null) {
                // Found the updated attachment! Check if its file exists
                if (File(match.path).existsSync()) {
                  return PlatformFile(
                    name: match.transferName!,
                    path: match.path,
                    size: match.totalBytes ?? 0,
                  );
                }
              }
            } catch (e) {
              // If lookup fails, continue to fallback below
            }
          }

          // Last resort: search for file by name in attachment directories
          // This is less precise but handles edge cases
          try {
            final attachmentsDir = Directory(FilesystemSvc.attachmentsPath);
            if (attachmentsDir.existsSync()) {
              final dirs = attachmentsDir.listSync().whereType<Directory>();
              for (final dir in dirs) {
                final fileName = attachment.transferName;
                if (fileName != null) {
                  final potentialFile = File("${dir.path}/$fileName");
                  if (potentialFile.existsSync() &&
                      (attachment.totalBytes == null || potentialFile.lengthSync() == attachment.totalBytes)) {
                    return PlatformFile(
                      name: fileName,
                      path: potentialFile.path,
                      size: attachment.totalBytes ?? 0,
                    );
                  }
                }
              }
            }
          } catch (e) {
            // If search fails, fall through to return attachment
          }
        }
        return attachment;
      }
    }

    if (attachment.guid?.contains("demo") ?? false) {
      return PlatformFile(
        name: attachment.transferName!,
        path: null,
        size: attachment.totalBytes ?? 0,
        bytes: Uint8List.fromList([]),
      );
    }

    if (kIsWeb || attachment.guid == null) {
      if (attachment.bytes == null && (autoDownload ?? SettingsSvc.settings.autoDownload.value)) {
        // Only start a download when there is actually a GUID to request from the server.
        // Pre-picked / ephemeral attachments (guid == null) cannot be downloaded; returning
        // the bare Attachment here will show a placeholder in the UI rather than crashing.
        if (attachment.guid != null) {
          return AttachmentDownloader.startDownload(attachment, onComplete: onComplete);
        }
        // No GUID and no bytes — return a PlatformFile with whatever path is available.
        return PlatformFile(
          name: attachment.transferName!,
          path: path,
          size: attachment.totalBytes ?? 0,
        );
      } else {
        return PlatformFile(
          name: attachment.transferName!,
          path: path,
          size: attachment.totalBytes ?? 0,
          bytes: attachment.bytes,
        );
      }
    }

    final pathName = path ?? attachment.path;
    final localFile = File(pathName);
    final convertedFile = File(attachment.convertedPath);
    final hasLocalFile = localFile.existsSync() || convertedFile.existsSync();

    // Prefer local file presence over the persisted flag because isDownloaded can
    // drift out of sync with filesystem state (e.g. failed display / stale DB flag).
    if ((attachment.isDownloaded == true && hasLocalFile) || hasLocalFile) {
      // For images, check if we need HEIC/TIFF conversion
      String? compatiblePath = pathName;
      if (attachment.mimeType?.contains('image/hei') ?? false) {
        final convertedPath = "$pathName.png";
        if (File(convertedPath).existsSync()) {
          compatiblePath = convertedPath;
        } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          // iOS/macOS have native HEIC support
          compatiblePath = pathName;
        } else {
          // Will need conversion on first display
          compatiblePath = pathName;
        }
      } else if (attachment.mimeType?.contains('image/tif') ?? false) {
        final convertedPath = "$pathName.png";
        if (File(convertedPath).existsSync()) {
          compatiblePath = convertedPath;
        } else {
          // Will need conversion on first display
          compatiblePath = pathName;
        }
      } else if (!localFile.existsSync() && convertedFile.existsSync()) {
        // Fallback when original file is gone but converted file remains.
        compatiblePath = attachment.convertedPath;
      }

      return PlatformFile(
        name: attachment.transferName!,
        path: compatiblePath,
        size: attachment.totalBytes ?? 0,
      );
      // Check for existing download controller
    } else if (AttachmentDownloader.getController(attachment.guid) != null) {
      return AttachmentDownloader.getController(attachment.guid);
    } else if (autoDownload ?? SettingsSvc.settings.autoDownload.value) {
      return AttachmentDownloader.startDownload(attachment, onComplete: onComplete);
    } else {
      return attachment;
    }
  }

  String createAppleLocation(double longitude, double latitude) {
    List<String> lines = [
      "BEGIN:VCARD",
      "VERSION:3.0",
      "PRODID:-//Apple Inc.//macOS 13.0//EN",
      "N:;Current Location;;;",
      "FN:Current Location",
      "URL;type=pref:https://maps.apple.com/?ll=$longitude\\,$latitude&q=$longitude\\,$latitude",
      "END:VCARD",
      "",
    ];
    return lines.join("\n");
  }

  String? parseAppleLocationUrl(String appleLocation) {
    final lines = appleLocation.split("\n");
    final line = lines.firstWhereOrNull((e) => e.contains("URL"));
    if (line != null) {
      return line.split("pref:").last;
    } else {
      return null;
    }
  }

  ContactV2 parseAppleContact(String appleContact) {
    final contact = VCardStack.fromData(appleContact).items.first;
    final nameVals = contact.findFirstProperty(VConstants.name)?.values;
    final c = ContactV2(
      nativeContactId: randomString(8),
      displayName: contact.findFirstProperty(VConstants.formattedName)?.values.firstOrNull ?? "Unknown",
      firstName: nameVals?.elementAtOrNull(1),
      lastName: nameVals?.elementAtOrNull(0),
      middleName: nameVals?.elementAtOrNull(2),
      namePrefix: nameVals?.elementAtOrNull(3),
      nameSuffix: nameVals?.elementAtOrNull(4),
    );
    c.phoneNumbers = (contact.findFirstProperty(VConstants.phone)?.values ?? [])
        .map((v) => ContactPhone(number: v.toString(), label: ''))
        .toList();
    c.emailAddresses = (contact.findFirstProperty(VConstants.email)?.values ?? [])
        .map((v) => ContactEmail(address: v.toString(), label: ''))
        .toList();
    return c;
  }

  Future<void> saveToDisk(PlatformFile file, {bool isAutoDownload = false, bool isDocument = false}) async {
    if (kIsWeb) {
      final content = base64.encode(file.bytes!);
      // create a fake download element and "click" it
      html.AnchorElement(href: "data:application/octet-stream;charset=utf-16le;base64,$content")
        ..setAttribute("download", file.name)
        ..click();
    } else if (kIsDesktop) {
      String? savePath = await FilePicker.saveFile(
        initialDirectory: await FilesystemSvc.downloadsDirectory,
        dialogTitle: 'Choose a location to save this file',
        fileName: file.name,
        lockParentWindow: true,
        type: file.extension != null ? FileType.custom : FileType.any,
        allowedExtensions: file.extension != null ? [file.extension!] : null,
      );

      if (savePath == null) {
        return showSnackbar('Error', 'You didn\'t select a file path!');
      } else if (await File(savePath).exists()) {
        await showBBDialog(
          context: Get.context!,
          barrierDismissible: false,
          title: "Confirm save",
          body: "This file already exists.\nAre you sure you want to overwrite it?",
          actions: <BBDialogAction>[
            BBDialogAction(
              text: "No",
              onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(),
            ),
            BBDialogAction(
              text: "Yes",
              isDefault: true,
              onPressed: () async {
                if (file.path != null) {
                  await File(file.path!).copy(savePath);
                } else {
                  await File(savePath).writeAsBytes(file.bytes!);
                }
                Navigator.of(Get.context!, rootNavigator: true).pop();
                showSnackbar(
                  'Success',
                  'Saved attachment to $savePath!',
                  durationMs: 3000,
                  button: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Get.theme.colorScheme.surfaceVariant,
                    ),
                    onPressed: () {
                      launchUrl(Uri.file(savePath));
                    },
                    child: Text("OPEN FILE", style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant)),
                  ),
                );
              },
            ),
          ],
        );
      } else {
        if (file.path != null) {
          await File(file.path!).copy(savePath);
        } else {
          await File(savePath).writeAsBytes(file.bytes!);
        }
        showSnackbar(
          'Success',
          'Saved attachment to $savePath!',
          durationMs: 3000,
          button: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.surfaceVariant,
            ),
            onPressed: () {
              launchUrl(Uri.file(savePath));
            },
            child: Text("OPEN FILE", style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant)),
          ),
        );
      }
    } else {
      String? savePath;

      if (SettingsSvc.settings.askWhereToSave.value && !isAutoDownload) {
        savePath = await FilePicker.getDirectoryPath(
          initialDirectory: SettingsSvc.settings.autoSaveDocsLocation.value,
          dialogTitle: 'Choose a location to save this file',
          lockParentWindow: true,
        );
      } else {
        if (file.name.toLowerCase().endsWith(".mov")) {
          savePath = join(FilesystemService.androidDownloadsPath, SettingsSvc.settings.autoSavePicsLocation.value);
        } else {
          if (!isDocument) {
            try {
              if (file.path == null && file.bytes != null) {
                await SaverGallery.saveImage(file.bytes!,
                    quality: 100,
                    fileName: file.name,
                    androidRelativePath: SettingsSvc.settings.autoSavePicsLocation.value,
                    skipIfExists: false);
              } else {
                await SaverGallery.saveFile(
                    filePath: file.path!,
                    fileName: file.name,
                    androidRelativePath: SettingsSvc.settings.autoSavePicsLocation.value,
                    skipIfExists: false);
              }
              return showSnackbar('Success', 'Saved attachment to gallery!');
            } catch (_) {}
          }
          savePath = SettingsSvc.settings.autoSaveDocsLocation.value;
        }
      }

      if (savePath != null) {
        final bytes = file.bytes != null && file.bytes!.isNotEmpty ? file.bytes! : await File(file.path!).readAsBytes();
        await File(join(savePath, file.name)).writeAsBytes(bytes);
        showSnackbar('Success', 'Saved attachment to ${FilesystemSvc.toDisplayPath(savePath)} folder!');
      } else {
        return showSnackbar('Error', 'You didn\'t select a file path!');
      }
    }
  }

  Future<bool> canAutoDownload() async {
    final canSave = (await Permission.storage.request()).isGranted;
    if (!canSave) return false;
    if (!SettingsSvc.settings.autoDownload.value) {
      return false;
    } else {
      if (!SettingsSvc.settings.onlyWifiDownload.value) {
        return true;
      } else {
        List<ConnectivityResult> status = await (Connectivity().checkConnectivity());
        return status.contains(ConnectivityResult.wifi);
      }
    }
  }

  Future<void> redownloadAttachment(Attachment attachment,
      {Function(PlatformFile)? onComplete, Function()? onError}) async {
    if (attachment.guid == null || attachment.guid!.startsWith('temp')) {
      return;
    }

    // Clear in-memory payload so stale bytes are not treated as a completed file.
    attachment.bytes = null;

    if (!kIsWeb) {
      final file = File(attachment.path);
      final pngFile = File(attachment.convertedPath);
      final thumbnail = File("${attachment.path}.thumbnail");
      final pngThumbnail = File("${attachment.convertedPath}.thumbnail");
      final partial = File("${attachment.path}.part");

      try {
        if (await file.exists()) await file.delete();
        if (await pngFile.exists()) await pngFile.delete();
        if (await thumbnail.exists()) await thumbnail.delete();
        if (await pngThumbnail.exists()) await pngThumbnail.delete();
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
    }

    bool updateAttachment = false;
    if (attachment.isDownloaded == true) {
      attachment.isDownloaded = false;
      updateAttachment = true;
    }

    // Clear metadata processing flag and cached dimensions to force reprocessing
    if (attachment.metadata != null) {
      attachment.metadata!.remove('_dimensions_processed');
      updateAttachment = true;
    }

    if (attachment.height != null || attachment.width != null) {
      attachment.height = null;
      attachment.width = null;
      updateAttachment = true;
    }

    // Force EXIF reload on the next properties pass.
    if (attachment.exif != null) {
      attachment.exif = null;
      updateAttachment = true;
    }

    if (updateAttachment) {
      await attachment.saveAsync(null);
    }

    // Always clear any stale controller/queue entry so this redownload starts fresh.
    AttachmentDownloader.clearControllerForGuid(attachment.guid!);
    AttachmentDownloader.startDownload(
      attachment,
      onComplete: onComplete,
      onError: onError,
      forceFresh: true,
    );
  }

  Future<Size> getImageSizing(String filePath, Attachment attachment) async {
    try {
      dynamic file = File(filePath);
      final sizeResult = await isg.ImageSizeGetter.getSizeResultAsync(AsyncInput(FileInput(file)));
      final size = sizeResult.size;
      return Size(size.needRotate ? size.height.toDouble() : size.width.toDouble(),
          size.needRotate ? size.width.toDouble() : size.height.toDouble());
    } catch (ex) {
      return const Size(0, 0);
    }
  }

  /// In-memory cache of video thumbnail bytes keyed by video file path, so widgets can render a
  /// previously-loaded thumbnail synchronously (no async disk read → no placeholder flash).
  final Map<String, Uint8List> _videoThumbnailMemCache = {};
  static const int _videoThumbnailMemCacheMax = 64;

  Uint8List? getCachedVideoThumbnailSync(String filePath) => _videoThumbnailMemCache[filePath];

  /// Clears the in-memory video thumbnail cache. Call after bulk-deleting
  /// attachment files so stale bytes aren't served for paths that no longer
  /// exist on disk.
  void clearVideoThumbnailCache() => _videoThumbnailMemCache.clear();

  void _memCacheVideoThumbnail(String filePath, Uint8List bytes) {
    _videoThumbnailMemCache.remove(filePath);
    _videoThumbnailMemCache[filePath] = bytes;
    if (_videoThumbnailMemCache.length > _videoThumbnailMemCacheMax) {
      _videoThumbnailMemCache.remove(_videoThumbnailMemCache.keys.first);
    }
  }

  Future<Uint8List?> getVideoThumbnail(String filePath, {bool useCachedFile = true}) async {
    final cachedFile = File("$filePath.thumbnail");
    if (useCachedFile) {
      final memCached = _videoThumbnailMemCache[filePath];
      if (memCached != null) return memCached;
      try {
        final bytes = await cachedFile.readAsBytes();
        if (!_isLowResThumbnail(bytes)) {
          _memCacheVideoThumbnail(filePath, bytes);
          return bytes;
        }
      } catch (_) {}
    }

    final thumbnail = await VideoThumbnail.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.PNG,
      maxWidth: 512, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
      quality: 25,
    );

    if (!isNullOrEmpty(thumbnail) && useCachedFile) {
      _memCacheVideoThumbnail(filePath, thumbnail!);
      await cachedFile.writeAsBytes(thumbnail);
    }

    return thumbnail;
  }

  /// Thumbnails were historically generated at 128px, which looks blurry now that video previews
  /// render at message-bubble size — treat those disk caches as stale so they get regenerated.
  bool _isLowResThumbnail(Uint8List bytes) {
    try {
      final size = isg.ImageSizeGetter.getSizeResult(isg.MemoryInput(bytes)).size;
      return size.width < 256 && size.height < 256;
    } catch (_) {
      return false;
    }
  }

  /// Converts HEIC/TIFF images to PNG if needed (only on platforms that don't support them natively).
  /// Also extracts image dimensions and metadata lazily.
  /// Returns the path to use (converted or original), or null if conversion failed.
  Future<String?> ensureImageCompatibility(Attachment attachment, {String? actualPath}) async {
    if (kIsWeb || attachment.mimeType == null || attachment.mimeStart != "image") {
      return actualPath ?? attachment.path;
    }

    final filePath = actualPath ?? attachment.path;
    File originalFile = File(filePath);

    // Create parent directory if needed (desktop)
    if (kIsDesktop && !await originalFile.parent.exists()) {
      await originalFile.parent.create(recursive: true);
    }

    // TIFF: Always needs conversion (Flutter doesn't support TIFF natively on any platform)
    if (attachment.mimeType!.contains('image/tif')) {
      final convertedPath = "$filePath.png";
      if (await File(convertedPath).exists()) {
        return convertedPath;
      }

      // Convert TIFF to PNG
      try {
        final image = await ImageInterface.convertToPng(PlatformFile(
          name: attachment.transferName ?? 'image.tiff',
          path: originalFile.path,
          size: attachment.totalBytes ?? 0,
        ));

        if (image != null) {
          await File(convertedPath).writeAsBytes(image);
          return convertedPath;
        }
      } catch (ex, stack) {
        Logger.error('Failed to convert TIFF!', error: ex, trace: stack);
      }
      return null;
    }

    // HEIC: Only convert on platforms that don't support it natively
    // Android 9+ and iOS have native support
    if (attachment.mimeType!.contains('image/hei')) {
      final convertedPath = "$filePath.png";

      // Check if we already converted this file
      if (await File(convertedPath).exists()) {
        return convertedPath;
      }

      // iOS/macOS: Native HEIC support, use original
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        return filePath;
      }

      // Android: Check API level (28+ has native support)
      // For now, convert all Android to be safe for older devices
      try {
        final file = await FlutterImageCompress.compressAndGetFile(
          filePath,
          convertedPath,
          format: CompressFormat.png,
          keepExif: true,
          quality: 100, // No quality loss for compatibility conversion
        );

        if (file == null) {
          Logger.error("Failed to convert HEIC!");
          return filePath; // Fallback to original, may not display on old devices
        }

        return convertedPath;
      } catch (ex, stack) {
        Logger.error('Failed to convert HEIC!', error: ex, trace: stack);
        return filePath; // Fallback to original
      }
    }

    // All other formats: use as-is
    return filePath;
  }

  Future<String?> loadImageProperties(Attachment attachment, {String? actualPath}) async {
    if (kIsWeb || attachment.mimeType == null || attachment.mimeStart != "image") {
      return null;
    }

    final filePath = actualPath ?? attachment.path;

    // Check if dimensions have already been processed.
    // We don't want to rely on the height/width or metadata alone because
    // it doesn't give the full picture of how to display the image (orientation, etc).
    // We need to "double-check" by reading EXIF and image properties directly.
    if (attachment.metadata?['_dimensions_processed'] == true) {
      return filePath;
    }

    // Ensure we have a compatible image file first
    final compatiblePath = await ensureImageCompatibility(attachment, actualPath: filePath);
    if (compatiblePath == null) return null;

    bool dimensionsLoaded = false;

    // Try to get dimensions and metadata from EXIF first (runs in isolate to avoid UI lag)
    if (attachment.mimeType != "image/gif") {
      try {
        final exif = await ImageInterface.readExifData(compatiblePath);
        if (exif != null) {
          // Extract dimensions from EXIF if available
          int? exifWidth;
          int? exifHeight;

          if (exif.containsKey('EXIF ExifImageWidth')) {
            exifWidth = int.tryParse(exif['EXIF ExifImageWidth']!);
          } else if (exif.containsKey('Image ImageWidth')) {
            exifWidth = int.tryParse(exif['Image ImageWidth']!);
          }

          if (exif.containsKey('EXIF ExifImageLength')) {
            exifHeight = int.tryParse(exif['EXIF ExifImageLength']!);
          } else if (exif.containsKey('Image ImageLength')) {
            exifHeight = int.tryParse(exif['Image ImageLength']!);
          }

          String? orientationStr;
          if (exif.containsKey('Image Orientation')) {
            orientationStr = exif['Image Orientation'];
          }

          // Check if dimensions need to be swapped based on orientation
          // Rotations of 90° or 270° require swapping width/height for display
          bool needsSwap = orientationStr != null &&
              (orientationStr.contains('90') ||
                  orientationStr.contains('270') ||
                  orientationStr.toLowerCase().contains('rotated 90') ||
                  orientationStr.toLowerCase().contains('rotated 270') ||
                  orientationStr.toLowerCase().contains('horizontal (normal)') ||
                  orientationStr.toLowerCase().contains('mirrored horizontal'));

          if (exifWidth != null && exifHeight != null) {
            if (needsSwap) {
              attachment.width = exifHeight;
              attachment.height = exifWidth;
            } else {
              attachment.width = exifWidth;
              attachment.height = exifHeight;
            }
            dimensionsLoaded = true;
          }

          attachment.exif = exif;
          await attachment.saveAsync(null);
        } else if (attachment.exif == null) {
          // Null means EXIF has never been loaded. Empty map means we attempted to load it.
          attachment.exif = {};
          await attachment.saveAsync(null);
        }
      } catch (ex, stack) {
        Logger.error('Failed to read EXIF data!', error: ex, trace: stack);
      }
    } else if (attachment.exif == null) {
      // GIFs don't produce EXIF data, but mark as processed for loaded-vs-unloaded semantics.
      attachment.exif = {};
      await attachment.saveAsync(null);
    }

    // Fallback: Get dimensions using image size getter if not loaded from EXIF
    if (!dimensionsLoaded && (attachment.width == null || attachment.height == null)) {
      if (attachment.mimeType == "image/gif") {
        try {
          // Read GIF dimensions in isolate (avoids loading full file into memory)
          final dimensions = await ImageInterface.getGifDimensions(compatiblePath);
          if (dimensions != null && dimensions['width'] != 0 && dimensions['height'] != 0) {
            attachment.width = dimensions['width'];
            attachment.height = dimensions['height'];
            dimensionsLoaded = true;
          }
        } catch (ex, stack) {
          Logger.error('Failed to get GIF dimensions!', error: ex, trace: stack);
        }
      } else {
        try {
          Size size = await getImageSizing(compatiblePath, attachment);
          if (size.width != 0 && size.height != 0) {
            attachment.width = size.width.toInt();
            attachment.height = size.height.toInt();
            dimensionsLoaded = true;
          }
        } catch (ex, stack) {
          Logger.error('Failed to get Image Properties!', error: ex, trace: stack);
        }
      }
    }

    // Mark dimensions as processed to avoid reprocessing
    if (dimensionsLoaded) {
      attachment.metadata ??= {};
      attachment.metadata!['_dimensions_processed'] = true;
      await attachment.saveAsync(null);
    }

    return filePath;
  }
}
