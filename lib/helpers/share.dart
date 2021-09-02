import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as sp;

class Share {
  /// Share a file with other apps.
  static void file(String subject, String filepath) async {
    sp.Share.shareFiles([filepath], text: subject);
  }

  /// Share text with other apps.
  static void text(String subject, String text) {
    sp.Share.share(text, subject: subject);
  }

  static Future<void> location(Chat chat) async {
    // If we don't have a permission, return
    if (!(await Permission.locationWhenInUse.request().isGranted)) return;

    // Tell Android Native code to get us the last known location
    final result = await MethodChannelInterface().invokeMethod("get-last-location");

    if (result == null) {
      Logger.error("Failed to load last location!");
      return;
    }

    String vcfString = AttachmentHelper.createAppleLocation(result["latitude"], result["longitude"]);

    // Build out the file we are going to send
    String _attachmentGuid = "temp-${randomString(8)}";
    String fileName = "CL.loc.vcf";
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/$_attachmentGuid/$fileName";

    // Write the file to the app documents
    await new File(pathName).create(recursive: true);
    File attachmentFile = await new File(pathName).writeAsString(vcfString);

    // Create the attachment object
    List<int> bytes = await attachmentFile.readAsBytes();
    Attachment messageAttachment = Attachment(
      guid: _attachmentGuid,
      totalBytes: bytes.length,
      isOutgoing: true,
      isSticker: false,
      hideAttachment: false,
      uti: "public.jpg",
      transferName: fileName,
      mimeType: "text/x-vlocation",
    );

    // Create the message object and link the attachment
    Message sentMessage = Message(
        guid: _attachmentGuid,
        text: "",
        dateCreated: DateTime.now(),
        hasAttachments: true,
        attachments: [messageAttachment]);

    // Add the message to the chat and save
    NewMessageManager().addMessage(chat, sentMessage);
    await chat.addMessage(sentMessage);

    // Send message to the server to be sent out
    Map<String, dynamic> params = new Map();
    params["guid"] = chat.guid;
    params["attachmentGuid"] = _attachmentGuid;
    params["attachmentName"] = fileName;
    params["attachment"] = base64Encode(bytes);
    SocketManager().sendMessage("send-message", params, (data) {});
  }
}
