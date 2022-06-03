import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/location_widget.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
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
    String fileName = "$_attachmentGuid-CL.loc.vcf";
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
            size: kIsWeb ? bytes!.length : file!.lengthSync(),
            path: filePath,
            bytes: bytes,
          ),
          chat,
          "",
          null,
          null,
          null,
        ),
      ),
    );
  }

  static Future<void> locationDesktop(Chat chat) async {
    bool _serviceEnabled;
    LocationPermission _permissionGranted;
    Position _locationData;

    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      await Get.dialog(AlertDialog(
        contentPadding: EdgeInsets.all(5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        backgroundColor: Get.theme.colorScheme.secondary,
        content: Container(
          padding: EdgeInsets.only(top: 20, left: 10, right: 10),
          width: 150,
          child: Text(
            "Location Services must be enabled to send Locations",
            style: Get.textTheme.bodyText1,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("Cancel")),
          TextButton(onPressed: () async => await Geolocator.openLocationSettings(), child: Text("Open Settings"))
        ],
      ));
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await Geolocator.checkPermission();
    if (_permissionGranted == LocationPermission.denied) {
      await Get.dialog(AlertDialog(
        contentPadding: EdgeInsets.all(5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        backgroundColor: Get.theme.colorScheme.secondary,
        content: Container(
          padding: EdgeInsets.only(top: 20, left: 10, right: 10),
          width: 150,
          child: Text(
            "BlueBubbles needs the Location Permission to send Locations",
            style: Get.textTheme.bodyText1,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("Cancel")),
          TextButton(onPressed: () async => await Geolocator.openLocationSettings(), child: Text("Open Settings"))
        ],
      ));
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
    file = File(filePath)
      ..createSync()
      ..writeAsStringSync(vcfString);

    PlatformFile pFile = PlatformFile(
      name: fileName,
      size: file.lengthSync(),
      path: filePath,
    );

    await Get.dialog(AlertDialog(
      contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 15),
      titlePadding: EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      backgroundColor: Get.theme.colorScheme.secondary,
      title: Text("Send Location?", style: Get.textTheme.headline1),
      content: Container(
        width: 150,
        child: LocationWidget(file: pFile, showOpen: false),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text("Cancel")),
        TextButton(
            onPressed: () {
              send = true;
              Get.back();
            },
            child: Text("Send"))
      ],
    ));
    if (!send) return;

    OutgoingQueue().add(
      QueueItem(
        event: "send-attachment",
        item: AttachmentSender(
          pFile,
          chat,
          "",
          null,
          null,
          null,
        ),
      ),
    );
  }
}
