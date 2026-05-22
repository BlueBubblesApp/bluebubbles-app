import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/services/backend/java_dart_interop/intents_service.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:faker/faker.dart' hide Image;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/services/backend/notifications/notifications_service.dart';

/// Map from call uuid to a closure that pops the dialog using the dialog's
/// OWN Navigator (captured inside the builder). Previously this stored a
/// `Route` and called `Get.removeRoute`, but `Get.removeRoute` searches via
/// the global navigator delegate, which can miss dialogs pushed against
/// `Get.context` — so the overlay stayed un-dismissable even after the user
/// tapped Accept/Ignore. Storing a direct pop-closure is unambiguous: it
/// always targets the right Navigator.
Map<String, VoidCallback> faceTimeOverlays = {};

/// Hides the FaceTime overlay with the given [callUuid]
/// Also calls [NotificationsService.clearFaceTimeNotification] to clear the notification
void hideFaceTimeOverlay(String callUuid) {
  notif.clearFaceTimeNotification(callUuid);
  final dismiss = faceTimeOverlays.remove(callUuid);
  if (dismiss != null) dismiss();
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
    builder: (dialogContext) {
      // Capture the dialog's OWN Navigator via its context. Using a
      // pop-closure (instead of a Route + Get.removeRoute) is unambiguous:
      // Navigator.of(dialogContext).pop() always targets the dialog itself,
      // regardless of which navigator delegate Get currently considers
      // active. The previous code stored a Route and called
      // Get.removeRoute, which can silently no-op when the navigator
      // delegate doesn't match — leaving the overlay un-dismissable.
      faceTimeOverlays[callUuid] = () {
        if (Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        }
      };
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
                // Dismiss the overlay first so the user is never stuck staring
                // at an un-dismissable dialog while answerFaceTime runs its
                // HTTP call.
                hideFaceTimeOverlay(callUuid);
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
    }).then((_) => faceTimeOverlays.remove(callUuid));
}
