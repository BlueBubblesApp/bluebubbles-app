import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/location_widget.dart';
import 'package:bluebubbles/services/backend/queue/outgoing_queue.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
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
    bool _serviceEnabled;
    LocationPermission _permissionGranted;
    Position _locationData;

    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      await showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          backgroundColor: Get.theme.colorScheme.properSurface,
          title: Text("Location Services", style: Get.textTheme.titleLarge,),
          content: Text(
            "Location Services must be enabled to send Locations",
            style: Get.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary))),
            TextButton(onPressed: () async => await Geolocator.openLocationSettings(), child: Text("Open Settings", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)))
          ],
        )
      );
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await Geolocator.checkPermission();
    if (_permissionGranted == LocationPermission.denied) {
      _permissionGranted = await Geolocator.requestPermission();
    }
    if (_permissionGranted == LocationPermission.denied || _permissionGranted == LocationPermission.deniedForever) {
      await showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          backgroundColor: Get.theme.colorScheme.properSurface,
          title: Text("Location Permission", style: Get.textTheme.titleLarge),
          content: Text(
            "BlueBubbles needs the Location permission to send Locations",
            style: Get.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text("Cancel", style: Get.textTheme.bodyLarge!.copyWith(color: Get.theme.colorScheme.primary))),
            TextButton(onPressed: () async => await Geolocator.openLocationSettings(), child: Text("Open Settings", style: Get.textTheme.bodyLarge!.copyWith(color: Get.theme.colorScheme.primary)))
          ],
        )
      );
      if (_permissionGranted != LocationPermission.whileInUse && _permissionGranted != LocationPermission.always) {
        return;
      }
    }

    _locationData = await Geolocator.getCurrentPosition();
    bool send = false;
    String vcfString = AttachmentHelper.createAppleLocation(_locationData.latitude, _locationData.longitude);

    // Build out the file we are going to send
    String _attachmentGuid = "temp-${randomString(8)}";
    String fileName = "$_attachmentGuid-CL.loc.vcf";
    File? file;
    String? filePath;

    filePath = "${AttachmentHelper.getTempPath()}/$fileName";
    file = File(filePath);
    await file.create();
    await file.writeAsString(vcfString);

    final bytes = await file.readAsBytes();
    PlatformFile pFile = PlatformFile(
      name: fileName,
      size: bytes.length,
      path: filePath,
      bytes: bytes,
    );

    await showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        backgroundColor: Get.theme.colorScheme.properSurface,
        title: Text("Send Location?", style: Get.textTheme.titleLarge),
        content: Container(
          width: 150,
          child: LocationWidget(file: pFile, showOpen: false),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("Cancel", style: Get.textTheme.bodyLarge!.copyWith(color: Get.theme.colorScheme.primary))),
          TextButton(
              onPressed: () {
                send = true;
                Get.back();
              },
              child: Text("Send", style: Get.textTheme.bodyLarge!.copyWith(color: Get.theme.colorScheme.primary)))
        ],
      )
    );
    if (!send) return;

    final message = Message(
      guid: _attachmentGuid,
      text: "",
      dateCreated: DateTime.now(),
      hasAttachments: true,
      attachments: [
        Attachment(
          guid: _attachmentGuid,
          isOutgoing: true,
          isSticker: false,
          hideAttachment: false,
          uti: "public.jpg",
          bytes: bytes,
          transferName: fileName,
        ),
      ],
      isFromMe: true,
      handleId: 0,
    );

    outq.queue(OutgoingItem(
      type: QueueType.sendAttachment,
      chat: chat,
      message: message,
    ));
  }
}
