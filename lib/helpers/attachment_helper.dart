import 'dart:convert';
import 'dart:io' show File;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/simple_vcard_parser.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart' hide File;
import 'package:video_thumbnail/video_thumbnail.dart';

class AppleLocation {
  double? longitude;
  double? latitude;

  AppleLocation({required this.latitude, required this.longitude});
}

class AttachmentHelper {
  static String createAppleLocation(double? longitude, double? latitude, {iosVersion = "13.4.1"}) {
    List<String> lines = [
      "BEGIN:VCARD",
      "VERSION:3.0",
      "PRODID:-//Apple Inc.//iPhone OS $iosVersion//EN",
      "N:;Current Location;;;",
      "FN:Current Location",
      "item1.URL;type=pref:http://maps.apple.com/?ll=$longitude\\,$latitude&q=$longitude\\,$latitude",
      "item1.X-ABLabel:map url",
      "END:VCARD"
          ""
    ];

    return lines.join("\n");
  }

  static AppleLocation parseAppleLocation(String appleLocation) {
    List<String> lines = appleLocation.split("\n");

    try {
      String? url;
      for (var i in lines) {
        if (i.contains("URL:") || i.contains("URL;")) {
          url = i;
        }
      }

      if (url == null) return AppleLocation(latitude: null, longitude: null);

      String? query;
      List<String> opts = ["&q=", "&ll="];
      for (var i in opts) {
        if (url.contains(i)) {
          var items = url.split(i);
          if (items.isNotEmpty) {
            query = items[1];
          }
        }
      }

      if (query == null) return AppleLocation(latitude: null, longitude: null);
      if (query.contains("&")) {
        query = query.split("&").first;
      }

      if (query.contains("\\")) {
        return AppleLocation(
            latitude: double.tryParse(query.split("\\,")[1]), longitude: double.tryParse(query.split("\\,")[0]));
      } else {
        return AppleLocation(
            latitude: double.tryParse(query.split(",")[1]), longitude: double.tryParse(query.split(",")[0]));
      }
    } catch (ex) {
      Logger.error("Failed to parse location!");
      Logger.error(ex.toString());
      return AppleLocation(latitude: null, longitude: null);
    }
  }

  static Contact parseAppleContact(String appleContact) {
    VCard _contact = VCard(appleContact);
    _contact.printLines();

    Contact contact = Contact(displayName: _contact.formattedName ?? "Unknown", id: randomString(8));

    List<String> emails = <String>[];
    List<String> phones = <String>[];

    // Parse emails from results
    for (dynamic email in _contact.typedEmail) {
      emails.add(email[0]);
    }

    // Parse phone numbers from results
    for (dynamic phone in _contact.typedTelephone) {
      phones.add(phone[0]);
    }

    contact.phones = phones;
    contact.emails = emails;

    return contact;
  }

  static bool canCompress(Attachment attachment) {
    String mime = attachment.mimeType ?? "";
    List<String> blacklist = ["image/gif"];
    return mime.startsWith("image/") && !blacklist.contains(mime);
  }

  static double getImageAspectRatio(BuildContext context, Attachment attachment) {
    double width = attachment.width?.toDouble() ?? 0.0;
    double factor = attachment.height?.toDouble() ?? 0.0;
    if (attachment.width == null || attachment.width == 0 || attachment.height == null || attachment.height == 0) {
      width = CustomNavigator.width(context);
      factor = 2;
    }

    return (width / factor) / width;
  }

  static Future<void> saveToGallery(PlatformFile file, {bool showAlert = true}) async {
    if (kIsWeb) {
      final content = base64.encode(file.bytes!);
      html.AnchorElement(href: "data:application/octet-stream;charset=utf-16le;base64,$content")
        ..setAttribute("download", file.name)
        ..click();
      return;
    }
    if (kIsDesktop) {
      String? savePath = await FilePicker.platform.saveFile(
        initialDirectory: (await getDownloadsDirectory())?.path,
        dialogTitle: 'Choose a location to save this file',
        fileName: file.name,
      );
      Logger.info(savePath);
      if (savePath != null) {
        File(file.path!).copy(savePath);
        return showSnackbar('Success', 'Saved attachment to $savePath!');
      }
      return showSnackbar('Failed', 'You didn\'t select a file path!');
    }
    void showDeniedSnackbar({String? err}) {
      if (showAlert) showSnackbar("Save Failed", err ?? "Failed to save attachment!");
    }

    var hasPermissions = await Permission.storage.isGranted;
    var permDenied = await Permission.storage.isPermanentlyDenied;

    // If we don't have the permission, but it isn't permanently denied, prompt the user
    if (!hasPermissions && !permDenied) {
      PermissionStatus response = await Permission.storage.request();
      hasPermissions = response.isGranted;
      permDenied = response.isPermanentlyDenied;
    }

    // If we still don't have the permission or we are permanently denied, show the snackbar error
    if (!hasPermissions || permDenied) {
      return showDeniedSnackbar(err: "BlueBubbles does not have the required permissions!");
    }

    if (file.path == null) {
      return showDeniedSnackbar();
    }

    if (SettingsManager().settings.askWhereToSave.value && showAlert) {
      dynamic dir = Directory("/storage/emulated/0/");
      String? path = await FilesystemPicker.open(
        title: 'Save to folder',
        context: Get.context!,
        rootDirectory: dir,
        fsType: FilesystemType.folder,
        pickText: 'Save file',
        folderIconColor: Theme.of(Get.context!).primaryColor,
      );
      if (path != null) {
        final bytes = await File(file.path!).readAsBytes();
        await File(join(path, file.name)).writeAsBytes(bytes);
      }
      return;
    }

    try {
      await ImageGallerySaver.saveFile(file.path!);
      if (showAlert) showSnackbar('Success', 'Saved attachment to gallery!');
    } catch (_) {
      File toSave = File("/storage/emulated/0/Download/${file.name}");
      await toSave.create(recursive: true);
      final bytes = await File(file.path!).readAsBytes();
      await toSave.writeAsBytes(bytes);
      if (showAlert) showSnackbar('Success', 'Saved attachment to downloads folder!');
    }
  }

  static String getBaseAttachmentsPath() {
    String appDocPath = SettingsManager().appDocDir.path;
    return "$appDocPath/attachments";
  }

  static String getAttachmentPath(Attachment attachment) {
    String fileName = attachment.transferName ?? randomString(8);
    return "${getBaseAttachmentsPath()}/${attachment.guid}/$fileName";
  }

  /// Checks to see if an [attachment] exists in our attachment filesystem
  static bool attachmentExists(Attachment attachment) {
    if (kIsWeb) return false;
    String pathName = AttachmentHelper.getAttachmentPath(attachment);
    return !(FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound);
  }

  static dynamic getContent(Attachment attachment, {String? path, bool autoDownload = true}) {
    if (kIsWeb && attachment.bytes == null && attachment.guid != "redacted-mode-demo-attachment" && autoDownload) {
      return Get.put(AttachmentDownloadController(attachment: attachment), tag: attachment.guid);
    } else if (kIsWeb) {
      return PlatformFile(
        name: attachment.transferName!,
        path: attachment.guid == "redacted-mode-demo-attachment" ? "dummy path" : null,
        size: attachment.totalBytes ?? 0,
        bytes: attachment.bytes,
      );
    }
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = path ?? "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    if (Get.find<AttachmentDownloadService>().downloaders.contains(attachment.guid)) {
      return Get.find<AttachmentDownloadService>().getController(attachment.guid);
    } else if (!kIsWeb &&
        (FileSystemEntity.typeSync(pathName) != FileSystemEntityType.notFound ||
            attachment.guid == "redacted-mode-demo-attachment" ||
            (attachment.guid != null && attachment.guid!.contains("theme-selector")))) {
      return PlatformFile(
        name: attachment.transferName!,
        path: pathName,
        size: attachment.totalBytes ?? 0,
      );
    } else if ((attachment.mimeType == null || attachment.mimeType!.startsWith("text/")) && autoDownload) {
      return Get.put(AttachmentDownloadController(attachment: attachment), tag: attachment.guid);
    } else {
      return attachment;
    }
  }

  static IconData getIcon(String mimeType) {
    if (mimeType.isEmpty) {
      return SettingsManager().settings.skin.value == Skins.iOS
          ? CupertinoIcons.arrow_up_right_square
          : Icons.open_in_new;
    }
    if (mimeType == "application/pdf") {
      return SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.doc_on_doc : Icons.picture_as_pdf;
    } else if (mimeType == "application/zip") {
      return SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.folder : Icons.folder;
    } else if (mimeType.startsWith("audio")) {
      return SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.music_note : Icons.music_note;
    } else if (mimeType.startsWith("image")) {
      return SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.photo : Icons.photo;
    } else if (mimeType.startsWith("video")) {
      return SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.videocam : Icons.videocam;
    } else if (mimeType.startsWith("text")) {
      return SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.doc_text : Icons.note;
    }
    return SettingsManager().settings.skin.value == Skins.iOS
        ? CupertinoIcons.arrow_up_right_square
        : Icons.open_in_new;
  }

  static Future<bool> canAutoDownload() async {
    ConnectivityResult status = await (Connectivity().checkConnectivity());

    // If auto-download is enabled
    // and (only wifi download is disabled or
    // only wifi download enabled, and we have wifi)
    return (SettingsManager().settings.autoDownload.value &&
        (!SettingsManager().settings.onlyWifiDownload.value ||
            (SettingsManager().settings.onlyWifiDownload.value && status == ConnectivityResult.wifi)));
  }

  static void redownloadAttachment(Attachment attachment, {Function()? onComplete, Function()? onError}) {
    if (!kIsWeb) {
      File file = File(attachment.getPath());
      File jpgFile = File(attachment.getHeicToJpgPath());

      // If neither exist, don't do anything
      bool fExists = file.existsSync();
      bool cExists = jpgFile.existsSync();
      if (!fExists && !cExists) return;

      // Delete them if they exist
      if (fExists) file.deleteSync();
      if (cExists) jpgFile.deleteSync();
    }

    // Redownload the attachment
    Get.put(AttachmentDownloadController(attachment: attachment, onComplete: onComplete, onError: onError),
        tag: attachment.guid);
  }

  static Future<Uint8List?> getVideoThumbnail(String filePath, {bool useCachedFile = true}) async {
    File cachedFile = File("$filePath.thumbnail");
    if (useCachedFile) {
      if (cachedFile.existsSync()) {
        return cachedFile.readAsBytes();
      }
    }

    Uint8List? thumbnail = await VideoThumbnail.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.JPEG,
      quality: SettingsManager().compressionQuality,
    );

    if (thumbnail == null || thumbnail.isEmpty || thumbnail.lengthInBytes == 0) {
      throw Exception('Video thumbnail is empty!');
    }
  
    if (useCachedFile) {
      cachedFile.writeAsBytes(thumbnail);
    }

    return thumbnail;
  }

  static Future<Size> getImageSizingFallback(String filePath, {Uint8List? bytes}) async {
    try {
      if (!kIsWeb) {
        dynamic file = File(filePath);
        isg.Size size = await isg.AsyncImageSizeGetter.getSize(AsyncFileInput(file));
        return Size(size.width.toDouble(), size.height.toDouble());
      } else {
        isg.Size size = await isg.AsyncImageSizeGetter.getSize(AsyncMemoryInput(bytes!));
        return Size(size.width.toDouble(), size.height.toDouble());
      }
    } catch (ex) {
      return Size(0, 0);
    }
  }

  static Future<Size> getImageSizing(String filePath, {ImageProperties? properties, Uint8List? bytes}) async {
    try {
      double width = 0;
      double height = 0;
      if (!kIsWeb && !kIsDesktop) {
        ImageProperties size = properties ?? await FlutterNativeImage.getImageProperties(filePath);
        width = (size.width ?? 0).toDouble();
        height = (size.height ?? 0).toDouble();
      }

      if (width == 0 || height == 0) {
        return await AttachmentHelper.getImageSizingFallback(filePath, bytes: bytes);
      }

      return Size(width, height);
    } catch (_) {
      return await AttachmentHelper.getImageSizingFallback(filePath, bytes: bytes);
    }
  }

  static String getTempPath() {
    String dir = SettingsManager().appDocDir.path;
    Directory tempAssets = Directory("$dir/tempAssets");
    if (!tempAssets.existsSync()) {
      tempAssets.createSync();
    }

    return tempAssets.absolute.path;
  }

  static Future<File> tryCopyTempFile(File oldFile) async {
    // Pull the filename from the Uri. If we can't, just return the original file
    String? ogFilename = getFilenameFromUri(oldFile.absolute.path);
    if (ogFilename == null) return oldFile;
    // Build the new path
    String newPath = '${AttachmentHelper.getTempPath()}/$ogFilename';
    // If the paths are the same, return the original file
    if (oldFile.absolute.path == newPath) return oldFile;

    // Otherwise, copy the file to the new path
    return await oldFile.copy(newPath);
  }

  static Future<Uint8List?> compressAttachment(Attachment attachment, String filePath,
      {int? qualityOverride, bool getActualPath = true}) async {
    if (kIsWeb || attachment.mimeType == null) return null;
    attachment.metadata ??= {};

    // Make sure the attachment is an image or video
    String mimeStart = attachment.mimeType!.split("/").first;
    if (!["image", "video"].contains(mimeStart)) return null;

    // If we want the actual path, get it
    if (getActualPath) {
      filePath = AttachmentHelper.getAttachmentPath(attachment);
    }

    dynamic originalFile = File(filePath);

    // If we don't get the actual path, it's a dummy "attachment" and we need to copy it locally
    if (!getActualPath) {
      originalFile = await tryCopyTempFile(originalFile);
      filePath = originalFile.absolute.path;
    }

    // Handle getting heic images
    if ((attachment.mimeType == 'image/heic' || attachment.mimeType == 'image/heif') && !kIsWeb && !kIsDesktop) {
      if (await File(filePath + ".jpg").exists()) {
        originalFile = File(filePath + ".jpg");
      } else {
        final file = await FlutterNativeImage.compressImage(
          filePath,
          percentage: 100,
          quality: 100,
        );
        final cacheFile = File(filePath + ".jpg");
        final bytes = await file.readAsBytes();
        await cacheFile.writeAsBytes(bytes);
        originalFile = file;
      }
    }

    Uint8List previewData = await originalFile.readAsBytes();

    if ((attachment.mimeType?.endsWith("tif") ?? false) || (attachment.mimeType?.endsWith("tiff") ?? false)) {
      final receivePort = ReceivePort();
      await Isolate.spawn(
          unsupportedToPngIsolate,
          IsolateData(
              PlatformFile(
                name: randomString(8),
                path: originalFile.path,
                size: 0,
              ),
              receivePort.sendPort));
      // Get the processed image from the isolate.
      final image = await receivePort.first as Uint8List?;
      previewData = image ?? previewData;
    }
    if (attachment.mimeType == "image/gif") {
      try {
        Size size = getGifDimensions(previewData);
        if (size.width != 0 && size.height != 0) {
          attachment.width = size.width.toInt();
          attachment.height = size.height.toInt();
        }
      } catch (ex) {
        Logger.error('Failed to get GIF dimensions! Error: ${ex.toString()}');
      }
    } else if (mimeStart == "image") {
      // For images, load properties
      try {
        ImageProperties? props;
        if (!kIsWeb && !kIsDesktop) {
          props = await FlutterNativeImage.getImageProperties(filePath);
          String orientation = props.orientation.toString();
          if (orientation == '0') {
            attachment.metadata!['orientation'] = 'landscape';
          } else if (orientation == '1') {
            attachment.metadata!['orientation'] = 'portrait';
          }
        }
        Size size = await getImageSizing(filePath, properties: props);
        if (size.width != 0 && size.height != 0) {
          attachment.width = size.width.toInt();
          attachment.height = size.height.toInt();
        }
      } catch (ex) {
        Logger.error('Failed to get Image Properties! Error: ${ex.toString()}');
      }
    }

    // Map the EXIF to the metadata
    try {
      Map<String, IfdTag> exif = await readExifFromFile(File(filePath));
      for (var item in exif.entries) {
        attachment.metadata![item.key] = item.value.printable;
      }
    } catch (ex) {
      Logger.error('Failed to read EXIF data: ${ex.toString()}');
    }

    // If we should update the attachment data, do it right before we return, no awaiting
    if (attachment.guid != null) {
      attachment.save(null);
    }

    // Return the bytes
    return previewData;
  }

  static double getAspectRatio(int? height, int? width, {BuildContext? context}) {
    double aspectRatio = 0.78;
    int aHeight = height ?? context?.height.toInt() ?? 0;
    int aWidth = width ?? context?.width.toInt() ?? 0;

    // If we somehow end up with 0 for either the height or width, return the default (16:9)
    if (aHeight == 0 || aWidth == 0) {
      return aspectRatio;
    }

    return (aWidth / aHeight).abs();
  }
}

void unsupportedToPngIsolate(IsolateData param) {
  try {
    final bytes = param.file.bytes ?? (kIsWeb ? null : File(param.file.path!).readAsBytesSync());
    if (bytes == null) {
      param.sendPort.send(null);
      return;
    }
    final image = img.decodeImage(bytes)!;
    final encoded = img.encodePng(image);
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

class ResizeArgs {
  final String path;
  final SendPort sendPort;
  final int width;

  ResizeArgs(this.path, this.sendPort, this.width);
}
