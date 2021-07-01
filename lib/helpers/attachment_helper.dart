import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/helpers/simple_vcard_parser.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_size_getter/image_size_getter.dart' as IMG;
import 'package:permission_handler/permission_handler.dart';

class AttachmentHelper {
  static String createAppleLocation(double longitude, double latitude, {iosVersion = "13.4.1"}) {
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

  static Map<String, double> parseAppleLocation(String appleLocation) {
    List<String> lines = appleLocation.split("\n");
    var emptyLocation = {'longitude': null, 'latitude': null};

    try {
      String url;
      for (var i in lines) {
        if (i.contains("URL:") || i.contains("URL;")) {
          url = i;
        }
      }

      if (url == null) return emptyLocation;

      String query;
      List<String> opts = ["&q=", "&ll="];
      for (var i in opts) {
        if (url.contains(i)) {
          var items = url.split(i);
          if (items.length >= 1) {
            query = items[1];
          }
        }
      }

      if (query == null) return emptyLocation;
      if (query.contains("&")) {
        query = query.split("&").first;
      }

      if (query.contains("\\")) {
        return {
          "longitude": double.tryParse((query.split("\\,")[0])),
          "latitude": double.tryParse(query.split("\\,")[1])
        };
      } else {
        return {"longitude": double.tryParse((query.split(",")[0])), "latitude": double.tryParse(query.split(",")[1])};
      }
    } catch (ex) {
      debugPrint("Faled to parse location!");
      debugPrint(ex.toString());
      return emptyLocation;
    }
  }

  static Contact parseAppleContact(String appleContact) {
    VCard info = VCard(appleContact);
    info.printLines();

    Contact contact = Contact();
    contact.displayName = info.formattedName;

    List<Email> emails = [];
    List<Phone> phones = [];
    List<Address> addresses = [];

    // Parse emails from results
    for (dynamic email in info.typedEmail) {
      EmailLabel label = EmailLabel.home;
      String customLabel;
      if (email.length > 1 && email[1].length > 0 && email[1][1] != null) {
        String realLabel = email[1][1];
        label = emailLabelMap.containsKey(email[1]) ? emailLabelMap[realLabel] : EmailLabel.custom;
        customLabel = realLabel;
      }

      emails.add(new Email(email[0], label: label, customLabel: customLabel));
    }

    // Parse phone numbers from results
    for (dynamic phone in info.typedTelephone) {
      PhoneLabel label = PhoneLabel.mobile;
      String customLabel;
      if (phone.length > 1 && phone[1].length > 0 && phone[1][1] != null) {
        String realLabel = phone[1][1];
        label = phoneLabelMap.containsKey(phone[1]) ? phoneLabelMap[realLabel] : PhoneLabel.custom;
        customLabel = realLabel;
      }

      phones.add(new Phone(phone[0], label: label, customLabel: customLabel));
    }

    // Parse addresses numbers from results
    for (dynamic address in info.typedAddress) {
      AddressLabel label = AddressLabel.home;
      String customLabel;
      if (address.length > 1 && address[1].length > 0 && address[1][1] != null) {
        String realLabel = address[1][1];
        label = addressLabelMap.containsKey(address[1]) ? addressLabelMap[realLabel] : PhoneLabel.custom;
        customLabel = realLabel;
      }

      addresses.add(new Address(address[0], label: label, customLabel: customLabel));
    }

    contact.phones = phones;
    contact.addresses = addresses;
    contact.emails = emails;

    return contact;
  }

  static String getPreviewPath(Attachment attachment) {
    String fileName = attachment.transferName;
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
      width = Get.mediaQuery.size.width;
      factor = 2;
    }

    return (width / factor) / width;
  }

  static Future<void> saveToGallery(BuildContext context, File file) async {
    if (await Permission.storage.request().isGranted) {
      await ImageGallerySaver.saveFile(file.absolute.path);
      showSnackbar('Success', 'Saved to gallery!');
    }
  }

  static String getBaseAttachmentsPath() {
    String appDocPath = SettingsManager().appDocDir.path;
    return "$appDocPath/attachments";
  }

  static String getAttachmentPath(Attachment attachment) {
    String fileName = attachment.transferName;
    return "${getBaseAttachmentsPath()}/${attachment.guid}/$fileName";
  }

  /// Checks to see if an [attachment] exists in our attachment filesystem
  static bool attachmentExists(Attachment attachment) {
    String pathName = AttachmentHelper.getAttachmentPath(attachment);
    return !(FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound);
  }

  static dynamic getContent(Attachment attachment, {String path}) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = path ?? "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";

    if (SocketManager().attachmentDownloaders.containsKey(attachment.guid)) {
      return SocketManager().attachmentDownloaders[attachment.guid];
    } else if (FileSystemEntity.typeSync(pathName) != FileSystemEntityType.notFound) {
      return File(pathName);
    } else if (attachment.mimeType == null || attachment.mimeType.startsWith("text/")) {
      return AttachmentDownloader(attachment);
    } else {
      return attachment;
    }
  }

  static IconData getIcon(String mimeType) {
    if (mimeType == null) return Icons.open_in_new;
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
    return (SettingsManager().settings.autoDownload &&
        (!SettingsManager().settings.onlyWifiDownload ||
            (SettingsManager().settings.onlyWifiDownload && status == ConnectivityResult.wifi)));
  }

  static Future<void> setDimensions(Attachment attachment, {Uint8List data}) async {
    // Handle break cases
    if (attachment.width != null && attachment.height != null && attachment.height != 0 && attachment.width != 0)
      return;
    if (attachment.mimeType == null) return;

    // Make sure the attachment is an image or video
    String mimeStart = attachment.mimeType.split("/").first;
    if (!["image", "video"].contains(mimeStart)) return;

    Uint8List previewData = data;
    if (data == null) {
      previewData = new File(AttachmentHelper.getAttachmentPath(attachment)).readAsBytesSync();
    }

    if (attachment.mimeType == "image/gif") {
      Size size = getGifDimensions(previewData);

      if (size.width != 0 && size.height != 0) {
        attachment.width = size.width.toInt();
        attachment.height = size.height.toInt();
      }
    } else if (mimeStart == "image") {
      IMG.Size size = IMG.ImageSizeGetter.getSize(IMG.MemoryInput(previewData));
      if (size.width != 0 && size.height != 0) {
        attachment.width = size.width;
        attachment.height = size.height;
      }
    } else if (mimeStart == "video") {
      IMG.Size size = await getVideoDimensions(attachment);
      if (size.width != 0 && size.height != 0) {
        attachment.width = size.width;
        attachment.height = size.height;
      }
    }
  }

  static Future<void> redownloadAttachment(Attachment attachment, {Function() onComplete, Function() onError}) async {
    // 1. Delete the old file
    File file = new File(attachment.getPath());
    if (!file.existsSync()) return;
    file.deleteSync();

    // 2. Redownload the attachment
    AttachmentDownloader(attachment, onComplete: onComplete, onError: onError);
  }
}
