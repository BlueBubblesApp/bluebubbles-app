import 'dart:io';
import 'package:connectivity/connectivity.dart';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:vcard_parser/vcard_parser.dart';

class AttachmentHelper {
  static String createAppleLocation(double longitude, double latitude,
      {iosVersion = "13.4.1"}) {
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
    String url = lines[5];
    String query = url.split("&q=")[1];

    if (query.contains("\\")) {
      return {
        "longitude": double.tryParse((query.split("\\,")[0])),
        "latitude": double.tryParse(query.split("\\,")[1])
      };
    } else {
      return {
        "longitude": double.tryParse((query.split(",")[0])),
        "latitude": double.tryParse(query.split(",")[1])
      };
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
        String label = key.contains("type=")
            ? key.split("type=")[2].replaceAll(";", "")
            : "HOME";
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
      String fn =
          fileName.split(".").sublist(0, fileName.length - 1).join("") + "prev";
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

  static double getImageAspectRatio(
      BuildContext context, Attachment attachment) {
    double width = attachment.width?.toDouble() ?? 0.0;
    double factor = attachment.height?.toDouble() ?? 0.0;
    if (attachment.width == null ||
        attachment.width == 0 ||
        attachment.height == null ||
        attachment.height == 0) {
      width = MediaQuery.of(context).size.width;
      factor = 2;
    }

    return (width / factor) / width;
  }

  static String getAttachmentPath(Attachment attachment) {
    String fileName = attachment.transferName;
    String appDocPath = SettingsManager().appDocDir.path;
    return "$appDocPath/attachments/${attachment.guid}/$fileName";
  }

  /// Checks to see if an [attachment] exists in our attachment filesystem
  static bool attachmentExists(Attachment attachment) {
    String pathName = AttachmentHelper.getAttachmentPath(attachment);
    return !(FileSystemEntity.typeSync(pathName) ==
        FileSystemEntityType.notFound);
  }

  static dynamic getContent(Attachment attachment, {String path}) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = path ??
        "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";

    /**
           * Case 1: If the file exists (we can get the type), add the file to the chat's attachments
           * Case 2: If the attachment is currently being downloaded, get the AttachmentDownloader object and add it to the chat's attachments
           * Case 3: If the attachment is a text-based one, automatically auto-download
           * Case 4: Otherwise, add the attachment, as is, meaning it needs to be downloaded
           */

    if (FileSystemEntity.typeSync(pathName) != FileSystemEntityType.notFound) {
      return File(pathName);
    } else if (SocketManager()
        .attachmentDownloaders
        .containsKey(attachment.guid)) {
      return SocketManager().attachmentDownloaders[attachment.guid];
    } else if (attachment.mimeType == null ||
        attachment.mimeType.startsWith("text/")) {
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
            (SettingsManager().settings.onlyWifiDownload &&
                status == ConnectivityResult.wifi)));
  }
}
