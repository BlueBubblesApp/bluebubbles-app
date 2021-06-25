import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraWidget extends StatefulWidget {
  final Function addAttachment;

  CameraWidget({
    Key key,
    @required this.addAttachment,
  }) : super(key: key);

  @override
  _CameraWidgetState createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> with WidgetsBindingObserver {
  CameraController controller;

  get hasCameraContext {
    return context != null && BlueBubblesTextField.of(context) != null;
  }

  @override
  void initState() {
    super.initState();
    initCameras();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initCameras() async {
    if (!this.hasCameraContext) return;
    await BlueBubblesTextField.of(context).initializeCameraController();
    if (!this.hasCameraContext) return; // After the await, so could have been some time
    if (this.mounted) setState(() {});
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Call the [LifeCycleManager] events based on the [state]
    if (state == AppLifecycleState.paused && controller != null) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCameras();
    }
  }

  @override
  void dispose() {
    if (controller != null) {
      debugPrint("Disposing of camera!");
      controller?.dispose();
    }
    super.dispose();
  }

  void showSnackbar(String text) {
    if (context == null) return;
    final snackBar = SnackBar(content: Text(text));
    Scaffold.of(context).showSnackBar(snackBar);
  }

  Future<void> openFullCamera({String type: 'camera'}) async {
    // Create a file that the camera can write to
    String appDocPath = SettingsManager().appDocDir.path;
    String ext = (type == 'video') ? ".mp4" : ".png";
    File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
    await file.create(recursive: true);

    // Take the picture after opening the camera
    await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": type});

    // If we don't get data back, return outta here
    if (!file.existsSync()) return;
    if (file.statSync().size == 0) {
      file.deleteSync();
      return;
    }

    widget.addAttachment(file);
  }

  @override
  Widget build(BuildContext context) {
    if (BlueBubblesTextField.of(context) == null) return Container();
    controller = BlueBubblesTextField.of(context).cameraController;

    if (controller == null || !controller.value.isInitialized) return Container();
    return AspectRatio(
      aspectRatio: Get.mediaQuery.orientation == Orientation.portrait
          ? (controller.value.previewSize.height / controller.value.previewSize.width)
          : 1 / (controller.value.previewSize.height / controller.value.previewSize.width),
      child: Stack(
        alignment: Alignment.topRight,
        children: _buildCameraStack(context),
      ),
    );
  }

  List<Widget> _buildCameraStack(BuildContext context) {
    if (SettingsManager().settings.redactedMode)
      return [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Get.theme.accentColor,
                child: Center(
                  child: Text("Camera"),
                ),
              ),
            ),
          ),
        ),
      ];

    return [
      Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          RotatedBox(
            child: CameraPreview(controller),
            quarterTurns: Get.mediaQuery.orientation == Orientation.portrait ? 0 : 3,
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: Get.mediaQuery.size.height / 30,
            ),
            child: FlatButton(
              color: Colors.transparent,
              onPressed: () async {
                HapticFeedback.mediumImpact();

                XFile savedImage = await controller.takePicture();
                File file = new File(savedImage.path);

                // Fail if the file doesn't exist after taking the picture
                if (!file.existsSync()) {
                  return this.showSnackbar('Failed to take picture! File improperly saved by Camera lib');
                }

                // Fail if the file size is equal to 0
                if (file.statSync().size == 0) {
                  file.deleteSync();
                  return this.showSnackbar('Failed to take picture! File was empty!');
                }

                // If all passes, add the attachment
                widget.addAttachment(file);
              },
              child: Icon(
                Icons.radio_button_checked,
                color: Colors.white,
                size: 30,
              ),
            ),
          )
        ],
      ),
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: Get.mediaQuery.size.height / 30,
          ),
          child: FlatButton(
            padding: EdgeInsets.only(left: 10),
            minWidth: 30,
            color: Colors.transparent,
            onPressed: () async {
              HapticFeedback.lightImpact();
              await this.openFullCamera(type: 'camera');
            },
            child: Icon(
              Icons.fullscreen,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: Get.mediaQuery.size.height / 30,
          ),
          child: FlatButton(
            padding: EdgeInsets.all(0),
            minWidth: 30,
            color: Colors.transparent,
            onPressed: () async {
              HapticFeedback.lightImpact();
              await this.openFullCamera(type: 'video');
            },
            child: Icon(
              Icons.videocam,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(
          bottom: Get.mediaQuery.size.height / 30,
        ),
        child: FlatButton(
          padding: EdgeInsets.only(right: 10),
          minWidth: 30,
          color: Colors.transparent,
          onPressed: () async {
            if (BlueBubblesTextField.of(context) == null) return;

            HapticFeedback.lightImpact();
            BlueBubblesTextField.of(context).cameraIndex = (BlueBubblesTextField.of(context).cameraIndex - 1).abs();
            await BlueBubblesTextField.of(context).initializeCameraController();
            if (this.mounted) setState(() {});
          },
          child: Icon(
            Icons.switch_camera,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    ];
  }
}
