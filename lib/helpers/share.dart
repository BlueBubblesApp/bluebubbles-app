import 'dart:convert';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:location/location.dart';
import 'package:share_plus/share_plus.dart' as sp;

class Share {
  /// Share a file with other apps.
  static void file(String subject, String filepath) async {
    if (kIsDesktop) {
      showSnackbar("Unsupported", "Can't share files on desktop yet!");
    } else {
      sp.Share.shareFiles([filepath], text: subject);
    }
  }

  /// Share text with other apps.
  static void text(String subject, String text) {
    sp.Share.share(text, subject: subject);
  }

  static Future<void> location(Chat chat) async {
    Location location = Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    String vcfString = AttachmentHelper.createAppleLocation(_locationData.latitude, _locationData.longitude);

    // Build out the file we are going to send
    String _attachmentGuid = "temp-${randomString(8)}";
    String fileName = "CL.loc.vcf";

    Attachment messageAttachment = Attachment(
      guid: _attachmentGuid,
      totalBytes: utf8.encode(vcfString).length,
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
      attachments: [messageAttachment],
      isFromMe: true,
      handleId: 0,
    );

    // Add the message to the chat and save
    NewMessageManager().addMessage(chat, sentMessage);
    await chat.addMessage(sentMessage);

    // Send message to the server to be sent out
    Map<String, dynamic> params = {};
    params["guid"] = chat.guid;
    params["attachmentGuid"] = _attachmentGuid;
    params["attachmentName"] = fileName;
    params["attachment"] = base64Encode(utf8.encode(vcfString));
    SocketManager().sendMessage("send-message", params, (data) {});
  }
}
