import 'dart:convert';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/image_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
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

// ignore: non_constant_identifier_names
AttachmentsService AttachmentsSvc = Get.isRegistered<AttachmentsService>()
    ? Get.find<AttachmentsService>()
    : Get.put(AttachmentsService());

/// Wrapper class for attachments being sent that includes both the file and send progress
class AttachmentWithProgress {
  final PlatformFile file;
  final AttachmentUploadProgress progress;

  AttachmentWithProgress(this.file, this.progress);
}

class AttachmentsService extends GetxService {
  /// The already-converted sibling of [basePath], if one is on disk. Checks the
  /// current format first, then the legacy `.png` older builds wrote for HEIC —
  /// those files decode fine, so there's no reason to reconvert.
  /// Null means nothing has been converted yet.
  String? _existingConvertedPath(Attachment attachment, String basePath) {
    for (final candidate in {"$basePath.${attachment.convertedExtension}", "$basePath.png"}) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Whether [attachment] (or its converted sibling) is already on disk at [path]
  /// (defaults to `attachment.path`). Read-only -- unlike [getContent], this never
  /// starts a download, so it's safe to call from a `build()`-time visibility check.
  bool hasLocalFile(Attachment attachment, {String? path}) {
    if (kIsWeb) return attachment.bytes != null;
    final pathName = path ?? attachment.path;
    return File(pathName).existsSync() || _existingConvertedPath(attachment, pathName) != null;
  }

  dynamic getContent(Attachment attachment, {String? path, bool? autoDownload, Function(PlatformFile)? onComplete}) {
    if (attachment.guid?.startsWith("temp") ?? false) {
      final sendProgress = OutgoingMsgHandler.attachmentProgress.firstWhereOrNull((e) => e.guid == attachment.guid);
      if (sendProgress != null) {
        // Check if we can also get the file to display behind the progress
        if (!kIsWeb) {
          final pathName = path ?? attachment.path;
          if (File(pathName).existsSync()) {
            final file = PlatformFile(name: attachment.transferName!, path: pathName, size: attachment.totalBytes ?? 0);
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
            return PlatformFile(name: attachment.transferName!, path: pathName, size: attachment.totalBytes ?? 0);
          }

          // If file doesn't exist at temp path, it may have been replaced with a real GUID
          // Try to find the updated attachment from the message
          // This is a fallback for when the UI still references the old temp attachment object
          if (attachment.message.target != null) {
            try {
              final message = attachment.message.target!;
              final messageAttachments = message.dbAttachments;
              final match = messageAttachments.firstWhereOrNull(
                (a) =>
                    !a.guid!.startsWith("temp") &&
                    a.transferName == attachment.transferName &&
                    a.totalBytes == attachment.totalBytes,
              );

              if (match != null) {
                // Found the updated attachment! Check if its file exists
                if (File(match.path).existsSync()) {
                  return PlatformFile(name: match.transferName!, path: match.path, size: match.totalBytes ?? 0);
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
                    return PlatformFile(name: fileName, path: potentialFile.path, size: attachment.totalBytes ?? 0);
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
        return PlatformFile(name: attachment.transferName!, path: path, size: attachment.totalBytes ?? 0);
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
    final convertedPath = _existingConvertedPath(attachment, pathName);
    final localFileExists = hasLocalFile(attachment, path: pathName);

    // Prefer local file presence over the persisted flag because isDownloaded can
    // drift out of sync with filesystem state (e.g. failed display / stale DB flag).
    if ((attachment.isDownloaded == true && localFileExists) || localFileExists) {
      // For images, check if we need HEIC/TIFF conversion. Both fall back to the
      // original when nothing has been converted yet — iOS/macOS decode HEIC
      // natively, and everywhere else conversion happens on first display.
      String? compatiblePath = pathName;
      final needsConversion =
          (attachment.mimeType?.contains('image/hei') ?? false) ||
          (attachment.mimeType?.contains('image/tif') ?? false);
      if (needsConversion) {
        compatiblePath = convertedPath ?? pathName;
      } else if (!File(pathName).existsSync() && convertedPath != null) {
        // Fallback when original file is gone but converted file remains.
        compatiblePath = convertedPath;
      }

      return PlatformFile(name: attachment.transferName!, path: compatiblePath, size: attachment.totalBytes ?? 0);
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
      }

      showSnackbar(
        'Success',
        'Saved attachment to $savePath!',
        durationMs: 3000,
        button: TextButton(
          style: TextButton.styleFrom(backgroundColor: Get.theme.colorScheme.surfaceVariant),
          onPressed: () {
            launchUrl(Uri.file(savePath));
          },
          child: Text("OPEN FILE", style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant)),
        ),
      );
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
                await SaverGallery.saveImage(
                  file.bytes!,
                  quality: 100,
                  fileName: file.name,
                  androidRelativePath: SettingsSvc.settings.autoSavePicsLocation.value,
                  skipIfExists: false,
                );
              } else {
                await SaverGallery.saveFile(
                  filePath: file.path!,
                  fileName: file.name,
                  androidRelativePath: SettingsSvc.settings.autoSavePicsLocation.value,
                  skipIfExists: false,
                );
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

  Future<void> redownloadAttachment(
    Attachment attachment, {
    Function(PlatformFile)? onComplete,
    Function()? onError,
  }) async {
    if (attachment.guid == null || attachment.guid!.startsWith('temp')) {
      return;
    }

    // Clear in-memory payload so stale bytes are not treated as a completed file.
    attachment.bytes = null;

    // Drop the cached VideoController -- its decode/aspect ratio is from the file we're
    // about to replace.
    final chatGuid = attachment.message.target?.chat.target?.guid;
    if (chatGuid != null && Get.isRegistered<ConversationViewController>(tag: chatGuid)) {
      Get.find<ConversationViewController>(tag: chatGuid).invalidateVideoPlayer(attachment.guid!);
    }

    if (!kIsWeb) {
      // Both conversion paths, since a file converted by an older build still
      // sits at the legacy `.png` location.
      final derived = {
        attachment.path,
        "${attachment.path}.thumbnail",
        "${attachment.path}.part",
        attachment.convertedPath,
        "${attachment.convertedPath}.thumbnail",
        attachment.legacyConvertedPath,
        "${attachment.legacyConvertedPath}.thumbnail",
      };

      try {
        for (final path in derived) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      } catch (_) {}
      // Sweeps every quality bucket, not just the current one.
      await deleteImagePreviews(attachment);
    }

    bool updateAttachment = false;
    if (attachment.isDownloaded == true) {
      attachment.isDownloaded = false;
      updateAttachment = true;
    }

    // Clear orientation/dimension processing flags and cached values to force reprocessing
    if (attachment.metadata != null) {
      attachment.metadata!.remove('_dimensions_processed');
      attachment.metadata!.remove('_orientation_processed');
      attachment.metadata!.remove('_orientation');
      attachment.metadata!.remove('_raw_width');
      attachment.metadata!.remove('_raw_height');
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
    AttachmentDownloader.startDownload(attachment, onComplete: onComplete, onError: onError, forceFresh: true);
  }

  /// Returns the RAW (decode-native, unrotated) pixel size read straight from
  /// the container/SOF header. This is the authoritative dimension source —
  /// EXIF dimension tags are metadata and can disagree with the actual pixels.
  Future<Size> getImageSizing(String filePath) async {
    try {
      dynamic file = File(filePath);
      final sizeResult = await isg.ImageSizeGetter.getSizeResultAsync(AsyncInput(FileInput(file)));
      final size = sizeResult.size;
      return Size(size.width.toDouble(), size.height.toDouble());
    } catch (ex) {
      return const Size(0, 0);
    }
  }

  /// Returns the on-disk thumbnail path for [filePath] if one already exists there, else null.
  /// A plain existence check -- disk is the only source of truth, so there's no cache to
  /// invalidate when a video gets redownloaded/replaced.
  String? getCachedVideoThumbnailSync(String filePath) {
    final cachedPath = "$filePath.thumbnail";
    return File(cachedPath).existsSync() ? cachedPath : null;
  }

  /// The filter chain behind every video thumbnail. Shared by the ffmpeg-kit path and the arm64
  /// Linux shell-out below so the two can't drift apart.
  ///
  /// Rotation is left to ffmpeg's default `-autorotate`, which handles iPhone .mov rotation flags
  /// correctly on its own.
  /// `thumbnail`: scans a short frame window for a non-blank one (iPhone clips often open on a
  /// black frame).
  /// `scale=iw*sar:ih,setsar=1`: bakes sample aspect ratio into pixel dimensions before the
  /// box-fit -- some .mov clips have non-1:1 SAR, and a plain `scale=W:H` ignores it, unlike real
  /// playback (mpv/media_kit), producing a wrongly-proportioned thumbnail.
  /// `scale=512:512:force_original_aspect_ratio=decrease`: the actual box-fit.
  static const _thumbnailFilter =
      'thumbnail,scale=iw*sar:ih,setsar=1,scale=512:512:force_original_aspect_ratio=decrease';

  static final _useSystemFfmpeg = Platform.isLinux && Platform.version.contains('linux_arm64');

  /// Generates (or reuses) a video thumbnail and returns the path to it on disk -- never loads
  /// the decoded thumbnail into memory as bytes, so callers must render it via [Image.file].
  ///
  /// When [useCachedFile] is true (the common case), the thumbnail is written next to the source
  /// video at `$filePath.thumbnail` and reused across calls. When false (e.g. a picker preview for
  /// a not-yet-sent attachment), a one-off thumbnail is written to the system temp directory
  /// instead, since the source file may live in a location that isn't safe/writable to cache
  /// alongside (e.g. the photo library).
  Future<String?> getVideoThumbnail(String filePath, {bool useCachedFile = true}) async {
    final cachedPath = "$filePath.thumbnail";
    if (useCachedFile) {
      final cachedExists = await File(cachedPath).exists();
      final cachedLowRes = cachedExists && await _isLowResThumbnailFile(cachedPath);
      if (cachedExists && !cachedLowRes) {
        return cachedPath;
      }
    }

    final destPath = useCachedFile
        ? cachedPath
        : join(FilesystemSvc.sysTempPath,
            "${basenameWithoutExtension(filePath)}_${DateTime.now().microsecondsSinceEpoch}.thumbnail.jpg");

    bool success;

    try {
      if (_useSystemFfmpeg) {
        // Process.run bypasses the shell and resolves `ffmpeg` on PATH, so the args go in as a
        // list and the paths need no quoting or escaping.
        final result = await Process.run('ffmpeg', [
          '-y',
          '-i', filePath,
          '-vf', _thumbnailFilter,
          '-frames:v', '1',
          '-q:v', '2',
          // Forces the output muxer -- the cached dest path has no image extension for ffmpeg to
          // infer a format from.
          '-f', 'mjpeg',
          destPath,
        ]);
        success = result.exitCode == 0;
        if (!success) {
          Logger.warn('ffmpeg thumbnail failed for $filePath (rc=${result.exitCode}) stderr=${result.stderr}',
              tag: 'VideoThumbnail');
        }
      } else {
        final command = '-y '
            '-i "${_ffmpegEscapePath(filePath)}" '
            '-vf "$_thumbnailFilter" '
            '-frames:v 1 -q:v 2 -f mjpeg '
            '"${_ffmpegEscapePath(destPath)}"';
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        success = ReturnCode.isSuccess(returnCode);
        if (!success) {
          final logs = await session.getAllLogsAsString();
          Logger.warn('ffmpeg thumbnail failed for $filePath (rc=$returnCode) command="$command" logs=$logs',
              tag: 'VideoThumbnail');
        }
      }
    } catch (ex, stacktrace) {
      Logger.error('ffmpeg thumbnail threw for $filePath -> $destPath', error: ex, trace: stacktrace, tag: 'VideoThumbnail');
      rethrow;
    }

    if (!success) return null;
    if (useCachedFile) {
      // FileImage caches decoded bytes by path only, not content -- evict so a thumbnail
      // regenerated at this same path (redownload, low-res cache-bust) isn't served stale.
      PaintingBinding.instance.imageCache.evict(FileImage(File(destPath)));
    }
    return destPath;
  }

  /// Escapes a path for safe interpolation inside a double-quoted ffmpeg command argument.
  String _ffmpegEscapePath(String path) => path.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  /// Thumbnails were historically generated at 128px, which looks blurry now that video previews
  /// render at message-bubble size — treat those disk caches as stale so they get regenerated.
  Future<bool> _isLowResThumbnailFile(String path) async {
    try {
      final sizeResult = await isg.ImageSizeGetter.getSizeResultAsync(AsyncInput(FileInput(File(path))));
      final size = sizeResult.size;
      return size.width < 256 && size.height < 256;
    } catch (ex) {
      Logger.debug('_isLowResThumbnailFile: could not read header for $path ($ex)', tag: 'VideoThumbnail');
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
        final image = await ImageInterface.convertToPng(
          PlatformFile(
            name: attachment.transferName ?? 'image.tiff',
            path: originalFile.path,
            size: attachment.totalBytes ?? 0,
          ),
        );

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
      // Checks the legacy `.png` too, so files converted by older builds are
      // reused rather than reconverted.
      final existing = _existingConvertedPath(attachment, filePath);
      if (existing != null) return existing;

      final convertedPath = "$filePath.${attachment.convertedExtension}";

      // iOS/macOS: Native HEIC support, use original
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        return filePath;
      }

      // Android: Check API level (28+ has native support)
      // For now, convert all Android to be safe for older devices
      try {
        // keepExif: false is load-bearing. autoCorrectionAngle defaults to
        // true, so the plugin has already rotated the pixels -- copying the
        // source Orientation tag onto the output would make Flutter's decoder
        // rotate a second time. This was the original orientation bug.
        //
        // JPEG, not PNG: camera photos have no alpha to preserve, and PNG
        // costs a full-resolution decode on every draw (see
        // Attachment.convertedExtension).
        final file = await FlutterImageCompress.compressAndGetFile(
          filePath,
          convertedPath,
          format: CompressFormat.jpeg,
          keepExif: false,
          quality: 90,
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

  /// Writes freshly-extracted dimensions onto the entity and, when the
  /// attachment has a live [AttachmentState], through that too — otherwise the
  /// reactive `width`/`height` pair silently goes stale against the DB record.
  void _applyDimensions(Attachment attachment, int width, int height) {
    attachment.width = width;
    attachment.height = height;

    final message = attachment.message.target;
    final chatGuid = message?.chat.target?.guid;
    final messageGuid = message?.guid;
    final attachmentGuid = attachment.guid;
    if (chatGuid == null || messageGuid == null || attachmentGuid == null) return;

    maybeFindMessagesSvc(chatGuid)?.getAttachmentState(messageGuid, attachmentGuid)?.updateDimensionsInternal(
      width,
      height,
    );
  }

  /// Property extractions currently running, keyed by file path. Fast scrolling
  /// otherwise fires one isolate EXIF read (plus possibly a HEIC conversion)
  /// per tile, each rebuilding its widget on completion.
  final Map<String, Future<String?>> _propertyJobs = {};

  Future<String?> loadImageProperties(Attachment attachment, {String? actualPath}) async {
    if (kIsWeb || attachment.mimeType == null || attachment.mimeStart != "image") {
      return null;
    }

    final filePath = actualPath ?? attachment.path;

    // Check if orientation/dimensions have already been processed.
    // We don't want to rely on the height/width or metadata alone because
    // it doesn't give the full picture of how to display the image (orientation, etc).
    // We need to "double-check" by reading EXIF and image properties directly.
    if (attachment.metadata?['_orientation_processed'] == true) {
      return filePath;
    }

    final inFlight = _propertyJobs[filePath];
    if (inFlight != null) return inFlight;

    final job = _loadImageProperties(attachment, filePath);
    _propertyJobs[filePath] = job;
    try {
      return await job;
    } finally {
      _propertyJobs.remove(filePath);
    }
  }

  Future<String?> _loadImageProperties(Attachment attachment, String filePath) async {
    final isGif = attachment.mimeType == "image/gif";

    // Step 1 -- EXIF, read from the ORIGINAL file before any format conversion
    // runs (in an isolate to avoid UI lag). Conversion can silently drop the
    // orientation tag, so reading post-conversion would lose it entirely.
    //
    // EXIF is the source of truth for ORIENTATION ONLY. Its dimension tags
    // (`ExifImageWidth`/`ExifImageLength`, `Image ImageWidth`) are metadata:
    // they go stale when an editor crops without rewriting EXIF, IFD0 often
    // describes the embedded thumbnail rather than the image, and both are
    // frequently absent. They are kept only as a last-resort fallback below.
    int orientation = 1;
    int? exifWidth;
    int? exifHeight;
    if (!isGif) {
      try {
        final result = await ImageInterface.readExifOrientation(filePath);
        if (result != null) {
          orientation = result['orientation'] as int? ?? 1;
          exifWidth = result['width'] as int?;
          exifHeight = result['height'] as int?;
          final raw = result['raw'];
          // Crossed an isolate boundary -- copy rather than hard-cast.
          attachment.exif = raw is Map ? Map<String, String>.from(raw) : <String, String>{};
        } else {
          // Null means EXIF has never been loaded. Empty map means we attempted to load it.
          attachment.exif ??= {};
        }
      } catch (ex, stack) {
        Logger.error('Failed to read EXIF orientation!', error: ex, trace: stack);
      }
    } else {
      // GIFs don't produce EXIF data, but mark as loaded for loaded-vs-unloaded semantics.
      attachment.exif ??= {};
    }

    // Step 2 -- resolve the file that will actually be decoded.
    final compatiblePath = await ensureImageCompatibility(attachment, actualPath: filePath);
    if (compatiblePath == null) return null;

    // A converted file has already had its rotation baked into the pixels
    // (flutter_image_compress's autoCorrectionAngle) and carries no
    // orientation tag, so it is upright. Recording the source's orientation
    // against those dimensions would swap them a second time.
    if (compatiblePath != filePath) {
      orientation = 1;
      exifWidth = null;
      exifHeight = null;
    }

    // Step 3 -- dimensions from the container/SOF header of the file we will
    // decode. This is ground truth; EXIF only fills in if it fails.
    int? rawWidth;
    int? rawHeight;
    if (isGif) {
      try {
        // Read GIF dimensions in isolate (avoids loading full file into memory)
        final dimensions = await ImageInterface.getGifDimensions(compatiblePath);
        if (dimensions != null && dimensions['width'] != 0 && dimensions['height'] != 0) {
          rawWidth = dimensions['width'];
          rawHeight = dimensions['height'];
        }
      } catch (ex, stack) {
        Logger.error('Failed to get GIF dimensions!', error: ex, trace: stack);
      }
    } else {
      try {
        final size = await getImageSizing(compatiblePath);
        if (size.width != 0 && size.height != 0) {
          rawWidth = size.width.toInt();
          rawHeight = size.height.toInt();
        }
      } catch (ex, stack) {
        Logger.error('Failed to get Image Properties!', error: ex, trace: stack);
      }
    }

    // Step 4 -- EXIF dimensions, only if the header read produced nothing.
    rawWidth ??= exifWidth;
    rawHeight ??= exifHeight;

    attachment.metadata ??= {};
    attachment.metadata!['_orientation'] = orientation;

    final dimensionsLoaded = rawWidth != null && rawHeight != null && rawWidth > 0 && rawHeight > 0;
    if (dimensionsLoaded) {
      attachment.metadata!['_raw_width'] = rawWidth;
      attachment.metadata!['_raw_height'] = rawHeight;
      _applyDimensions(attachment, rawWidth, rawHeight);
      // Only mark processed once we actually have dimensions, so a failed
      // read is retried on the next view rather than cached as "done".
      attachment.metadata!['_orientation_processed'] = true;
    }

    await attachment.saveAsync(null);

    return filePath;
  }

  /// Paths of previews already confirmed on disk this session, so a widget can
  /// decide synchronously whether to render the preview or the placeholder
  /// without an async stat. Only the fact of existence is held here — the
  /// bytes belong in Flutter's own `imageCache`, which knows how to evict them.
  final Set<String> _generatedPreviews = {};

  /// Preview generations currently running, keyed by preview path. Scroll churn
  /// recreates `_ImageViewerState`, so without this two generations can
  /// interleave writes to the same file.
  final Map<String, Future<String?>> _previewJobs = {};

  /// The preview path for [attachment] at the current quality setting, but only
  /// if it is already known to exist. Null means "render the placeholder and
  /// call [getOrCreateImagePreview]".
  String? knownPreviewPath(Attachment attachment) {
    final path = attachment.previewPathForQuality(_imagePreviewQuality);
    return _generatedPreviews.contains(path) ? path : null;
  }

  void clearImagePreviewCache() => _generatedPreviews.clear();

  // Preview resolution/quality both track the user's "image preview quality"
  // setting (0.25-1.0, same knob already used to scale inline cacheWidth
  // elsewhere), so a lower slider produces a smaller, more compressed -- and
  // thus faster-loading -- preview file.
  static const int _imagePreviewBaseMaxDimension = 1080;
  static const int _imagePreviewMinDimension = 270;

  int get _imagePreviewMaxDimension {
    final factor = SettingsSvc.settings.previewImageQuality.value;
    return (_imagePreviewBaseMaxDimension * factor)
        .round()
        .clamp(_imagePreviewMinDimension, _imagePreviewBaseMaxDimension)
        .toInt();
  }

  int get _imagePreviewQuality {
    final factor = SettingsSvc.settings.previewImageQuality.value;
    return (factor * 100).round().clamp(25, 100).toInt();
  }

  /// Deletes every generated preview for [attachment], across all quality
  /// buckets, and forgets them. Used when the source file is being replaced.
  Future<void> deleteImagePreviews(Attachment attachment) async {
    final prefix = "${attachment.path}.preview.";
    _generatedPreviews.removeWhere((p) => p.startsWith(prefix));
    try {
      final dir = Directory(attachment.directory);
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.startsWith(prefix)) await entity.delete();
      }
    } catch (_) {}
  }

  /// Returns the path to a downsampled preview file for [attachment]
  /// (resolution/JPEG quality driven by the user's preview image quality
  /// setting), generating + disk-caching it on first use.
  /// The original attachment file is never modified. Returns null if
  /// generation fails or isn't applicable (e.g. GIFs, which play natively
  /// and don't get a static preview).
  Future<String?> getOrCreateImagePreview(Attachment attachment, {String? actualPath}) async {
    if (kIsWeb || attachment.mimeType == null || attachment.mimeStart != "image") return null;
    if (attachment.mimeType == "image/gif") return null;

    final filePath = actualPath ?? attachment.path;
    // The filename carries the quality bucket, so moving the slider produces a
    // different path rather than silently reusing a preview at the old quality.
    final previewPath = attachment.previewPathForQuality(_imagePreviewQuality);

    final inFlight = _previewJobs[previewPath];
    if (inFlight != null) return inFlight;

    final job = _generateImagePreview(attachment, filePath, previewPath);
    _previewJobs[previewPath] = job;
    try {
      return await job;
    } finally {
      _previewJobs.remove(previewPath);
    }
  }

  Future<String?> _generateImagePreview(Attachment attachment, String filePath, String previewPath) async {
    if (await File(previewPath).exists()) {
      _generatedPreviews.add(previewPath);
      return previewPath;
    }
    if (!await File(filePath).exists()) return null;

    // Generate into a temp sibling and rename into place. Writing straight to
    // the final path means a kill mid-write leaves a truncated file that
    // exists() happily accepts forever.
    //
    // The `.jpg` has to stay last: flutter_image_compress asserts the target
    // filename matches the requested format, so a plain `.tmp` suffix would
    // throw in debug builds and silently produce no HEIC previews.
    final tempPath = "${previewPath.substring(0, previewPath.length - '.jpg'.length)}.tmp.jpg";
    final isHeic = attachment.mimeType!.contains('image/hei');
    bool ok = false;

    if (isHeic) {
      // HEIC: the `image` package can't decode HEIC, so use
      // flutter_image_compress directly -- it handles decode+rotate+resize
      // +encode in one native call. Not available on Windows/Linux (no
      // platform implementation for this plugin), so this is expected to
      // fail gracefully there -- callers fall back to the original file.
      try {
        // rotate: 0 -- flutter_image_compress's autoCorrectionAngle defaults
        // to true and already applies the source's EXIF orientation to the
        // pixels. Passing a rotation on top of that double-rotates.
        final result = await FlutterImageCompress.compressAndGetFile(
          filePath,
          tempPath,
          format: CompressFormat.jpeg,
          quality: _imagePreviewQuality,
          minWidth: _imagePreviewMaxDimension,
          minHeight: _imagePreviewMaxDimension,
          rotate: 0,
          keepExif: false,
        );
        ok = result != null;
      } catch (ex) {
        Logger.warn('Failed to generate HEIC image preview (platform may not support it): $ex');
        ok = false;
      }
    } else {
      try {
        ok = await ImageInterface.generatePreview(
          path: filePath,
          outputPath: tempPath,
          maxDimension: _imagePreviewMaxDimension,
          quality: _imagePreviewQuality,
        );
      } catch (ex, stack) {
        Logger.error('Failed to generate image preview!', error: ex, trace: stack);
        ok = false;
      }
    }

    if (!ok) {
      try {
        final temp = File(tempPath);
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      return null;
    }

    try {
      await File(tempPath).rename(previewPath);
    } catch (ex, stack) {
      Logger.error('Failed to move image preview into place!', error: ex, trace: stack);
      return null;
    }

    _generatedPreviews.add(previewPath);
    return previewPath;
  }
}
