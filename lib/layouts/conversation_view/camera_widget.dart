import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    initCameras();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initCameras() async {
    if (context == null) return;
    if (BlueBubblesTextField.of(context) == null) return;
    await BlueBubblesTextField.of(context).initializeCameraController();
    if (context == null) return; // After the await, so could have been some time
    controller = BlueBubblesTextField.of(context).cameraController;
    if (this.mounted) setState(() {});
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Call the [LifeCycleManager] events based on the [state]
    if (state == AppLifecycleState.paused) {
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

  @override
  Widget build(BuildContext context) {
    if (BlueBubblesTextField.of(context) == null) return Container();
    CameraController controller = BlueBubblesTextField.of(context).cameraController;
    if (controller == null || !controller.value.isInitialized) return Container();
    return AspectRatio(
      aspectRatio: MediaQuery.of(context).orientation == Orientation.portrait
          ? controller.value.aspectRatio
          : 1 / controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.topRight,
        children: <Widget>[
          Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              RotatedBox(
                child: CameraPreview(controller),
                quarterTurns: MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 3,
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height / 30,
                ),
                child: FlatButton(
                  color: Colors.transparent,
                  onPressed: () async {
                    String appDocPath = SettingsManager().appDocDir.path;

                    String pathName = "$appDocPath/tempAssets/${DateTime.now().toString()}.jpg";
                    await Directory("$appDocPath/tempAssets").create(recursive: true);

                    await controller.takePicture(pathName);

                    File file = new File(pathName);
                    if (!file.existsSync()) return;
                    if (file.statSync().size == 0) {
                      file.deleteSync();
                      return;
                    }

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
                bottom: MediaQuery.of(context).size.height / 30,
              ),
              child: FlatButton(
                padding: EdgeInsets.only(left: 10),
                minWidth: 30,
                color: Colors.transparent,
                onPressed: () async {
                  String appDocPath = SettingsManager().appDocDir.path;
                  File file = new File("$appDocPath/attachments/" + randomString(16) + ".png");
                  await file.create(recursive: true);
                  await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "camera"});

                  if (!file.existsSync()) return;
                  if (file.statSync().size == 0) {
                    file.deleteSync();
                    return;
                  }

                  widget.addAttachment(file);
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
                bottom: MediaQuery.of(context).size.height / 30,
              ),
              child: FlatButton(
                padding: EdgeInsets.all(0),
                minWidth: 30,
                color: Colors.transparent,
                onPressed: () async {
                  String appDocPath = SettingsManager().appDocDir.path;
                  File file = new File("$appDocPath/attachments/" + randomString(16) + ".mp4");
                  await file.create(recursive: true);
                  await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "video"});

                  if (!file.existsSync()) return;
                  if (file.statSync().size == 0) {
                    file.deleteSync();
                    return;
                  }

                  widget.addAttachment(file);
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
              bottom: MediaQuery.of(context).size.height / 30,
            ),
            child: FlatButton(
              padding: EdgeInsets.only(right: 10),
              minWidth: 30,
              color: Colors.transparent,
              onPressed: () async {
                if (BlueBubblesTextField.of(context) == null) return;

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
        ],
      ),
    );
  }
}
