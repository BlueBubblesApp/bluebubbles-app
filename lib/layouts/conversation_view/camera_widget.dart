import 'dart:io';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
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

class _CameraWidgetState extends State<CameraWidget> {
  @override
  void initState() {
    super.initState();
    initCameras();
  }

  Future<void> initCameras() async {
    if (BlueBubblesTextField.of(context) == null) return;
    await BlueBubblesTextField.of(context).initializeCameraController();
    if (this.mounted) setState(() {});
  }

  @override
  void dispose() {
    BlueBubblesTextField.of(context).cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BlueBubblesTextField.of(context) == null) return Container();
    CameraController controller =
        BlueBubblesTextField.of(context).cameraController;
    if (controller == null || !controller.value.isInitialized)
      return Container();
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
                quarterTurns:
                    MediaQuery.of(context).orientation == Orientation.portrait
                        ? 0
                        : 3,
              ),
              Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height / 30),
                child: FlatButton(
                  color: Colors.transparent,
                  onPressed: () async {
                    String appDocPath = SettingsManager().appDocDir.path;

                    String pathName =
                        "$appDocPath/tempAssets/${DateTime.now().toString()}.jpg";
                    await Directory("$appDocPath/tempAssets")
                        .create(recursive: true);

                    await controller.takePicture(pathName);
                    widget.addAttachment(File(pathName));
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
          Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height / 30),
            child: FlatButton(
              color: Colors.transparent,
              onPressed: () async {
                if (BlueBubblesTextField.of(context) == null) return;

                BlueBubblesTextField.of(context).cameraIndex =
                    (BlueBubblesTextField.of(context).cameraIndex - 1).abs();

                await BlueBubblesTextField.of(context)
                    .initializeCameraController();
                if (this.mounted) setState(() {});
              },
              child: Icon(
                Icons.switch_camera,
                color: Colors.white,
                size: 30,
              ),
            ),
          )
        ],
      ),
    );
  }
}
