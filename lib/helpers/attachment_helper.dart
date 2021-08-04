import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/helpers/simple_vcard_parser.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:exif/exif.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;
import 'package:permission_handler/permission_handler.dart';
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
          if (items.length >= 1) {
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
      debugPrint("Failed to parse location!");
      debugPrint(ex.toString());
      return AppleLocation(latitude: null, longitude: null);
    }
  }

  static Contact parseAppleContact(String appleContact) {
    VCard _contact = VCard(appleContact);
    _contact.printLines();

    Contact contact = Contact();
    contact.displayName = _contact.formattedName;

    List<Item> emails = <Item>[];
    List<Item> phones = <Item>[];
    List<PostalAddress> addresses = <PostalAddress>[];

    // Parse emails from results
    for (dynamic email in _contact.typedEmail) {
      String label = "HOME";
      if (email.length > 1 && email[1].length > 0 && email[1][1] != null) {
        label = email[1][1] ?? label;
      }

      emails.add(new Item(value: email[0], label: label));
    }

    // Parse phone numbers from results
    for (dynamic phone in _contact.typedTelephone) {
      String label = "HOME";
      if (phone.length > 1 && phone[1].length > 0 && phone[1][1] != null) {
        label = phone[1][1] ?? label;
      }

      phones.add(new Item(value: phone[0], label: label));
    }

    // Parse addresses numbers from results
    for (dynamic address in _contact.typedAddress) {
      String street = address[0].length > 0 ? address[0][0] : '';
      String city = address[0].length > 1 ? address[0][1] : '';
      String state = address[0].length > 2 ? address[0][2] : '';
      String country = address[0].length > 3 ? address[0][3] : '';

      String label = "HOME";
      if (address.length > 1 && address[1].length > 0 && address[1][1] != null) {
        label = address[1][1] ?? label;
      }

      addresses.add(new PostalAddress(label: label, street: street, city: city, region: state, country: country));
    }

    contact.phones = phones;
    contact.postalAddresses = addresses;
    contact.emails = emails;

    return contact;
  }

  static String getPreviewPath(Attachment attachment) {
    String fileName = attachment.transferName ?? randomString(8);
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = AttachmentHelper.getAttachmentPath(attachment);

    // If the file is an image, compress it for the preview
    if ((attachment.mimeType ?? "").startsWith("image/")) {
      String fn = fileName.split(".").sublist(0, fileName.length - 1).join("") + "prev";
      String ext = fileName.split(".").last;
      pathName = "$appDocPath/attachments/${attachment.guid}/$fn.$ext";
    }

    return pathName;
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
      width = context.width;
      factor = 2;
    }

    return (width / factor) / width;
  }

  static Future<void> saveToGallery(BuildContext context, File? file) async {
    Function showDeniedSnackbar = (String? err) {
      showSnackbar("Save Failed", err ?? "Failed to save attachment!");
    };

    if (file == null) {
      return showSnackbar("Save Failed", "No file to save!");
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
      return showDeniedSnackbar("BlueBubbles does not have the required permissions!");
    }

    await ImageGallerySaver.saveFile(file.absolute.path);
    showSnackbar('Success', 'Saved attachment!');
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
    String pathName = AttachmentHelper.getAttachmentPath(attachment);
    return !(FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound);
  }

  static dynamic getContent(Attachment attachment, {String? path}) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = path ?? "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";

    if (SocketManager().attachmentDownloaders.containsKey(attachment.guid)) {
      return SocketManager().attachmentDownloaders[attachment.guid];
    } else if (FileSystemEntity.typeSync(pathName) != FileSystemEntityType.notFound ||
        attachment.guid == "redacted-mode-demo-attachment" ||
        attachment.guid!.contains("theme-selector")) {
      return File(pathName);
    } else if (attachment.mimeType == null || attachment.mimeType!.startsWith("text/")) {
      return AttachmentDownloader(attachment);
    } else {
      return attachment;
    }
  }

  static IconData getIcon(String mimeType) {
    if (mimeType.isEmpty) return Icons.open_in_new;
    if (mimeType == "application/pdf") {
      return Icons.picture_as_pdf;
    } else if (mimeType == "application/zip") {
      return Icons.folder;
    } else if (mimeType.startsWith("audio")) {
      return Icons.music_note;
    } else if (mimeType.startsWith("image")) {
      return Icons.photo;
    } else if (mimeType.startsWith("video")) {
      return Icons.videocam;
    } else if (mimeType.startsWith("text")) {
      return Icons.note;
    }
    return Icons.open_in_new;
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

  static Future<void> redownloadAttachment(Attachment attachment, {Function()? onComplete, Function()? onError}) async {
    // 1. Delete the old file
    File file = new File(attachment.getPath());
    if (!file.existsSync()) return;
    file.deleteSync();

    // 2. Redownload the attachment
    AttachmentDownloader(attachment, onComplete: onComplete, onError: onError);
  }

  static Future<Uint8List?> getVideoThumbnail(String filePath) async {
    File cachedFile = new File("$filePath.thumbnail");
    if (cachedFile.existsSync()) {
      return cachedFile.readAsBytes();
    }
    Uint8List? thumbnail = await VideoThumbnail.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.JPEG,
      quality: SettingsManager().compressionQuality,
    );
    if (thumbnail != null) {
      cachedFile.writeAsBytes(thumbnail);
    }
    return thumbnail;
  }

  static Future<Size> getImageSizingFallback(String filePath) async {
    try {
      isg.Size size = isg.ImageSizeGetter.getSize(FileInput(File(filePath)));
      return Size(size.width.toDouble(), size.height.toDouble());
    } catch (ex) {
      return Size(0, 0);
    }
  }

  static Future<Size> getImageSizing(String filePath, {ImageProperties? properties}) async {
    try {
      ImageProperties size = properties ?? await FlutterNativeImage.getImageProperties(filePath);
      double width = (size.width ?? 0).toDouble();
      double height = (size.height ?? 0).toDouble();

      if (width == 0 || height == 0) {
        return AttachmentHelper.getImageSizingFallback(filePath);
      }

      return Size(width, height);
    } catch (_) {
      return AttachmentHelper.getImageSizingFallback(filePath);
    }
  }

  static Future<Uint8List?> compressAttachment(Attachment attachment, String filePath,
      {int? qualityOverride, bool getActualPath = true}) async {
    if (attachment.mimeType == null) return null;

    if (attachment.metadata == null) {
      attachment.metadata = {};
    }

    // Make sure the attachment is an image or video
    String mimeStart = attachment.mimeType!.split("/").first;
    if (!["image", "video"].contains(mimeStart)) return null;
    // Get byte data

    // Update sizing
    if (attachment.mimeType == "image/gif") {
      Uint8List previewData = getActualPath
          ? new File(AttachmentHelper.getAttachmentPath(attachment)).readAsBytesSync()
          : new File(filePath).readAsBytesSync();

      Size size = getGifDimensions(previewData);
      if (size.width != 0 && size.height != 0) {
        attachment.width = size.width.toInt();
        attachment.height = size.height.toInt();
      }

      return previewData;
    } else if (mimeStart == "image") {
      ImageProperties props = await FlutterNativeImage.getImageProperties(filePath);
      Size size = await getImageSizing(filePath, properties: props);
      if (size.width != 0 && size.height != 0) {
        attachment.width = size.width.toInt();
        attachment.height = size.height.toInt();
      }

      String orientation = props.orientation.toString();
      if (orientation == '0') {
        attachment.metadata!['orientation'] = 'landscape';
      } else if (orientation == '1') {
        attachment.metadata!['orientation'] = 'portrait';
      }
    } else if (mimeStart == "video") {
      Size size = await getVideoDimensions(filePath);
      if (size.width != 0 && size.height != 0) {
        attachment.width = size.width.toInt();
        attachment.height = size.height.toInt();
      }
      return null;
    }

    int quality = qualityOverride ?? SettingsManager().compressionQuality;
    // Check if the compressed file exists
    File cachedFile = new File("$filePath.${quality.toString()}.compressed");
    if (cachedFile.existsSync()) {
      return cachedFile.readAsBytes();
    }

    // Map the EXIF to the metadata
    Map<String, IfdTag> exif = await readExifFromFile(new File(filePath));
    for (var item in exif.entries) {
      attachment.metadata![item.key] = item.value.printable;
    }

    // Compress the file
    File compressedFile = await FlutterNativeImage.compressImage(filePath,
        quality: quality,
        percentage: SettingsManager().compressionQuality,
        targetWidth: attachment.width!,
        targetHeight: attachment.height!);

    // Read the compressed data, then cache it
    Uint8List data = await compressedFile.readAsBytes();
    cachedFile.writeAsBytes(data);

    // If we should update the attachment data, do it right before we return, no awaiting
    attachment.update();

    // Return the bytes
    return data;
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
