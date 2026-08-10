import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bluebubbles/models/models.dart' show LocationAttachmentData;
import 'package:universal_io/io.dart';

class Share {
  /// Share a file with other apps.
  static void files(List<String> filepaths, {String? mimeType}) async {
    if (kIsDesktop) {
      showSnackbar("Unsupported", "Can't share files on desktop yet!");
    } else {
      await SharePlus.instance
          .share(ShareParams(files: filepaths.map((String path) => XFile(path, mimeType: mimeType)).toList()));
    }
  }

  /// Share text with other apps.
  static void text(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  static Future<void> location(Chat chat) async {
    bool _serviceEnabled;
    LocationPermission _permissionGranted;
    Position _locationData;

    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      await showBBDialog(
          context: Get.context!,
          title: "Location Services",
          body: "Location Services must be enabled to send Locations",
          actions: [
            if (!kIsDesktop || !Platform.isLinux)
              BBDialogAction(
                text: "Cancel",
                onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(),
              ),
            if (!kIsDesktop || !Platform.isLinux)
              BBDialogAction(
                text: "Open Settings",
                isDefault: true,
                onPressed: () async => await Geolocator.openLocationSettings(),
              ),
            if (kIsDesktop && Platform.isLinux)
              BBDialogAction(
                text: "OK",
                onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(),
              ),
          ]);
      if (!_serviceEnabled) {
        return;
      }
    }

    if (!kIsDesktop || !Platform.isLinux) {
      _permissionGranted = await Geolocator.checkPermission();
      if (_permissionGranted == LocationPermission.denied) {
        _permissionGranted = await Geolocator.requestPermission();
      }
      if (_permissionGranted == LocationPermission.denied || _permissionGranted == LocationPermission.deniedForever) {
        await showBBDialog(
            context: Get.context!,
            title: "Location Permission",
            body: "BlueBubbles needs the Location permission to send Locations",
            actions: [
              BBDialogAction(
                text: "Cancel",
                onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(),
              ),
              BBDialogAction(
                text: "Open Settings",
                isDefault: true,
                onPressed: () async => await Geolocator.openLocationSettings(),
              ),
            ]);
        if (_permissionGranted == LocationPermission.denied || _permissionGranted == LocationPermission.deniedForever) {
          return;
        }
      }
    }

    String? _attachmentGuid;
    String? fileName;
    Uint8List? bytes;
    String? url;
    String? title;

    Future<LocationAttachmentData> getLocationPreview() async {
      _locationData = await Geolocator.getCurrentPosition();
      String vcfString = AttachmentsSvc.createAppleLocation(_locationData.latitude, _locationData.longitude);

      // Build out the file we are going to send
      String _attachmentGuid = "temp-${randomString(8)}";
      String fileName = "$_attachmentGuid-CL.loc.vcf";
      Uint8List bytes = Uint8List.fromList(utf8.encode(vcfString));

      // Apple Maps does not always serve a preview image; the location is
      // still perfectly sendable without one, so this is not treated as a
      // failure the way the old force-unwrap did (which left the dialog stuck
      // on "Loading Location..." forever).
      final meta = await MetadataHelper.getLocationMetadata(_locationData);

      return LocationAttachmentData(
        guid: _attachmentGuid,
        fileName: fileName,
        bytes: bytes,
        mapImageUrl: meta?.imageUrl,
        title: meta?.title,
      );
    }

    bool send = false;
    if (kIsDesktop || kIsWeb) {
      cvc(chat).showingOverlays = true;
    }
    await showDialog(
        context: Get.context!,
        builder: (context) => FutureBuilder(
            future: getLocationPreview(),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                _attachmentGuid = snapshot.data!.guid;
                fileName = snapshot.data!.fileName;
                bytes = snapshot.data!.bytes;
                url = snapshot.data!.mapImageUrl;
                title = snapshot.data!.title;
              }
              // Gate on the attachment itself rather than on the preview
              // image: a location with no thumbnail is still sendable.
              if (bytes == null) {
                return AbsorbPointer(
                  child: AlertDialog(
                    backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
                    title: Text(
                      snapshot.hasError ? "Couldn't Get Location" : "Loading Location...",
                      style: Get.textTheme.titleLarge,
                    ),
                    content: snapshot.hasError
                        ? Text("Check that location permissions are granted and try again.",
                            style: Get.textTheme.bodyMedium)
                        : buildProgressIndicator(context),
                  ),
                );
              }
              return AlertDialog(
                backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
                title: Text("Send Location?", style: Get.textTheme.titleLarge),
                content: SizedBox(
                  width: 150,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (url != null)
                        Image.network(
                          url!,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, _, _) {
                            return const SizedBox.shrink();
                          },
                          frameBuilder: (_, child, frame, _) {
                            if (frame == null) {
                              return Center(
                                heightFactor: 1,
                                child: buildProgressIndicator(context),
                              );
                            } else {
                              return child;
                            }
                          },
                        ),
                      if (url != null) const SizedBox(height: 15),
                      Text(
                        title ?? "No location details found",
                        style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(),
                      child: Text("Cancel",
                          style: Get.textTheme.bodyLarge!.copyWith(color: Get.theme.colorScheme.primary))),
                  TextButton(
                      onPressed: () {
                        send = true;
                        Navigator.of(Get.context!, rootNavigator: true).pop();
                      },
                      child:
                          Text("Send", style: Get.textTheme.bodyLarge!.copyWith(color: Get.theme.colorScheme.primary)))
                ],
              );
            }));
    if (kIsDesktop || kIsWeb) {
      cvc(chat).showingOverlays = false;
    }

    if (!send) return;
    if (bytes == null) return;

    final message = Message(
      guid: _attachmentGuid,
      text: "",
      dateCreated: DateTime.now(),
      hasAttachments: true,
      isFromMe: true,
      handleId: 0,
    );

    final attachment = Attachment(
      guid: _attachmentGuid,
      mimeType: "text/x-vlocation",
      isOutgoing: true,
      uti: "public.vlocation",
      bytes: bytes,
      transferName: fileName,
      totalBytes: bytes!.length,
    );

    OutgoingMsgHandler.queue(
      OutgoingAttachment(
        chat: chat,
        message: message,
        attachment: attachment,
      ),
    );
  }
}
