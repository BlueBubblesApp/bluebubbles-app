import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

/// Widget for the camera button that opens the device camera
class CameraButton extends StatelessWidget {
  final ConversationViewController controller;

  const CameraButton({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !context.iOS || !Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: () {
        openFullCamera(controller, type: 'video', context: context);
      },
      child: IconButton(
        padding: const EdgeInsets.only(left: 10),
        icon: Icon(
          CupertinoIcons.camera_fill,
          color: context.theme.colorScheme.outline,
          size: 28,
        ),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          openFullCamera(controller, type: 'camera', context: context);
        },
      ),
    );
  }
}

/// Utility function to handle opening the camera (extracted from main widget).
/// [context] is required for [Navigator.push] on Android.
Future<void> openFullCamera(
  ConversationViewController controller, {
  required String type,
  required BuildContext context,
}) async {
  bool granted = (await Permission.camera.request()).isGranted;
  if (!granted) {
    showSnackbar("Error", "Camera access was denied!", type: SnackbarType.error);
    return;
  }

  // Also request microphone permission when opening in video mode.
  if (type == 'video') {
    final micGranted = (await Permission.microphone.request()).isGranted;
    if (!micGranted) {
      showSnackbar("Error", "Microphone access was denied!", type: SnackbarType.error);
      return;
    }
  }

  final XFile? file;
  if (type == 'video') {
    file = await ImagePicker().pickVideo(source: ImageSource.camera);
  } else {
    file = await ImagePicker().pickImage(source: ImageSource.camera);
  }

  if (file != null) {
    controller.pickedAttachments.add(PlatformFile(
      path: file.path,
      name: file.path.split('/').last,
      size: await file.length(),
      bytes: await file.readAsBytes(),
    ));
  }
}
