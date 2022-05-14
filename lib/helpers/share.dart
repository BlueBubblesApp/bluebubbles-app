import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:share_plus/share_plus.dart' as sp;
import 'package:universal_io/io.dart';

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

    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    locationData = await location.getLocation();
    String vcfString = AttachmentHelper.createAppleLocation(locationData.latitude, locationData.longitude);

    // Build out the file we are going to send
    String attachmentGuid = "temp-${randomString(8)}";
    String fileName = "$attachmentGuid-CL.loc.vcf";
    File? file;
    String? filePath;
    Uint8List? bytes;
    if (!kIsWeb) {
      filePath = "${AttachmentHelper.getTempPath()}/$fileName";
      file = await (await File(filePath).create()).writeAsString(vcfString);
    } else {
      bytes = Uint8List.fromList(utf8.encode(vcfString));
    }

    OutgoingQueue().add(
      QueueItem(
        event: "send-attachment",
        item: AttachmentSender(
          PlatformFile(
            name: fileName,
            size: kIsWeb ? bytes!.length : await file!.length(),
            path: filePath,
            bytes: bytes,
          ),
          chat,
          "",
        ),
      ),
    );
  }
}
