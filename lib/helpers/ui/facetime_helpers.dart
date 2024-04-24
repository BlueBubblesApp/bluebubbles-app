import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/types/helpers/file_helpers.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/services/backend/java_dart_interop/intents_service.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:faker/faker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/services/backend/notifications/notifications_service.dart';

Map<String, Route> faceTimeOverlays = {}; // Map from call uuid to overlay route

/// Hides the FaceTime overlay with the given [callUuid]
/// Also calls [NotificationsService.clearFaceTimeNotification] to clear the notification
void hideFaceTimeOverlay(String callUuid) {
  notif.clearFaceTimeNotification(callUuid);
  if (faceTimeOverlays.containsKey(callUuid)) {
    Get.removeRoute(faceTimeOverlays[callUuid]!);
    faceTimeOverlays.remove(callUuid);
  }
}

/// Shows a FaceTime overlay with the given [callUuid], [caller], [chatIcon], and [isAudio]
/// Saves the overlay route in [faceTimeOverlays]
Future<void> showFaceTimeOverlay(String callUuid, String caller, Uint8List? chatIcon, bool isAudio) async {
  if (ss.settings.redactedMode.value && ss.settings.hideContactInfo.value) {
    if (chatIcon != null) chatIcon = null;
    caller = faker.person.name();
  }
  chatIcon ??= (await rootBundle.load("assets/images/person64.png")).buffer.asUint8List();
  chatIcon = await clip(chatIcon, size: 256, circle: true);

  // If we are somehow already showing an overlay for this call, close it
  hideFaceTimeOverlay(callUuid);

  showDialog(
    context: Get.context!,
    barrierDismissible: false,
    builder: (_) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: AlertDialog(
          icon: Image.memory(chatIcon!, width: 48, height: 48),
          title: Text(caller),
          content: Text(
            "Incoming FaceTime ${isAudio ? "Audio" : "Video"} Call",
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            MaterialButton(
              elevation: 0,
              hoverElevation: 0,
              color: Colors.green.withOpacity(0.2),
              splashColor: Colors.green,
              highlightColor: Colors.green.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 36.0),
              child: Column(
                children: [
                  Icon(
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.phone : Icons.call_outlined,
                    color: Colors.green,
                  ),
                  const Text(
                    "Accept",
                  ),
                ],
              ),
              onPressed: () async {
                await intents.answerFaceTime(callUuid);
              },
            ),
            const SizedBox(width: 16.0),
            MaterialButton(
              elevation: 0,
              hoverElevation: 0,
              color: Colors.red.withOpacity(0.2),
              splashColor: Colors.red,
              highlightColor: Colors.red.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 36.0),
              child: Column(
                children: [
                  Icon(
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.phone_down : Icons.call_end_outlined,
                    color: Colors.red,
                  ),
                  const Text(
                    "Ignore",
                  ),
                ],
              ),
              onPressed: () {
                hideFaceTimeOverlay(callUuid);
              },
            ),
          ],
        ),
      );
    }).then((_) => faceTimeOverlays.remove(callUuid) /* Not explicitly necessary since all ways of closing the dialog do this, but just in case */
  );

  // Save dialog as overlay route
  faceTimeOverlays[callUuid] = Get.rawRoute!;
}
