import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:connectivity/connectivity.dart';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vcard_parser/vcard_parser.dart';
import 'package:image_size_getter/image_size_getter.dart' as IMG;

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
    Map<String, dynamic> _contact = VcardParser(appleContact).parse();
    debugPrint(_contact.toString());

    Contact contact = Contact();
    if (_contact.containsKey("N") && _contact["N"].toString().isNotEmpty) {
      String firstName = (_contact["N"] + " ").split(";")[1];
      String lastName = _contact["N"].split(";")[0];
      contact.displayName = firstName + " " + lastName;
    } else if (_contact.containsKey("FN")) {
      contact.displayName = _contact["FN"];
    }

    List<Item> emails = <Item>[];
    List<Item> phones = <Item>[];
    _contact.keys.forEach((String key) {
      if (key.contains("EMAIL")) {
        String label = key.contains("type=") ? key.split("type=")[2].replaceAll(";", "") : "HOME";
        emails.add(
          Item(
            value: (_contact[key] as Map<String, dynamic>)["value"],
            label: label,
          ),
        );
      } else if (key.contains("TEL")) {
        phones.add(
          Item(
            label: "HOME",
            value: (_contact[key] as Map<String, dynamic>)["value"],
          ),
        );
      }
    });
    contact.emails = emails;
    contact.phones = phones;

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
      width = MediaQuery.of(context).size.width;
      factor = 2;
    }

    return (width / factor) / width;
  }

  static Future<void> saveToGallery(BuildContext context, File file) async {
    if (await Permission.storage.request().isGranted) {
      await ImageGallerySaver.saveFile(file.absolute.path);
      FlutterToast(context).showToast(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
                color: Theme.of(context).accentColor.withOpacity(0.1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    color: Theme.of(context).textTheme.bodyText1.color,
                  ),
                  SizedBox(
                    width: 12.0,
                  ),
                  Text(
                    "Saved to gallery",
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
