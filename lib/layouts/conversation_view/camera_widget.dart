import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class CameraWidget extends StatefulWidget {
  final Function addAttachment;

  CameraWidget({
    Key? key,
    required this.addAttachment,
  }) : super(key: key);

  @override
  _CameraWidgetState createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> with WidgetsBindingObserver {
  double? aspectRatioCache;
  get hasContext {
    return BlueBubblesTextField.of(context) != null;
  }

  get camerasAvailable {
    CameraController? controller = BlueBubblesTextField.of(context)!.cameraController;
    return controller != null && BlueBubblesTextField.of(context)?.cameraState == CameraState.ACTIVE;
  }

  @override
  void initState() {
    super.initState();

    // Bind the lifecycle events
    WidgetsBinding.instance!.addObserver(this);

    // The delay here just needs to be bigger than the SlideTransition
    new Future.delayed(const Duration(milliseconds: 400), () async {
      await initCameras();
    });
  }

  Future<void> initCameras() async {
    // If we aren't mounted or there is no context, don't do anything
    if (!this.mounted || !this.hasContext) return;
    // If the camera is already active, don't do anything
    if (BlueBubblesTextField.of(context)!.cameraState == CameraState.ACTIVE) return;

    // Initialize the camera
    await BlueBubblesTextField.of(context)!.initializeCameraController();

    // Update the state when finished
    if (!this.hasContext) return; // After the await, so could have been some time
    if (this.mounted) setState(() {});
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Call the [LifeCycleManager] events based on the [state]
    if (mounted && state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive && BlueBubblesTextField.of(context)!.cameraController != null) {
      await BlueBubblesTextField.of(context)!.disposeCameras();
    } else if (state == AppLifecycleState.resumed) {
      initCameras();
    }
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

  Widget cameraPlaceholder() {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(color: Theme.of(context).accentColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we don't have context, return the placeholder
    if (!this.hasContext) return cameraPlaceholder();
    CameraController? controller = BlueBubblesTextField.of(context)!.cameraController;

    // If the controller is null or the state is not active, return the placeholder
    List<Widget> cameraWidgets = [];
    double aspectRatio;
    if (controller == null || BlueBubblesTextField.of(context)?.cameraState != CameraState.ACTIVE) {
      cameraWidgets.add(cameraPlaceholder());
      aspectRatio = 0.6;
    } else {
      cameraWidgets = _buildCameraStack(context);
      if (aspectRatioCache != null) {
        aspectRatio = aspectRatioCache!;
      } else if (Get.mediaQuery.orientation == Orientation.portrait) {
        aspectRatio = controller.value.previewSize!.height / controller.value.previewSize!.width;
      } else {
        aspectRatio = 1 / controller.value.previewSize!.height / controller.value.previewSize!.width;
      }

      // Cache the aspect ratio so we don't have to calculate it again
      aspectRatioCache = aspectRatio;
    }

    return AnimatedOpacity(
        opacity: camerasAvailable ? 1 : 0.2, // 0.2 because then you can see the placeholder box a bit
        duration: Duration(milliseconds: 300), // 300 because I found that looked nice (in debug mode)
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            alignment: Alignment.topRight,
            children: cameraWidgets,
          ),
        ));
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
                color: Theme.of(context).accentColor,
                child: Center(
                  child: Text("Camera"),
                ),
              ),
            ),
          ),
        ),
      ];

    CameraController? controller = BlueBubblesTextField.of(context)!.cameraController;
    return [
      Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          RotatedBox(
            child: CameraPreview(controller!),
            quarterTurns: Get.mediaQuery.orientation == Orientation.portrait ? 0 : 3,
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: context.height / 30,
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();

                XFile savedImage = await controller.takePicture();
                File file = new File(savedImage.path);

                // Fail if the file doesn't exist after taking the picture
                if (!file.existsSync()) {
                  return showSnackbar('Error', 'Failed to take picture! File improperly saved by Camera lib');
                }

                // Fail if the file size is equal to 0
                if (file.statSync().size == 0) {
                  file.deleteSync();
                  return showSnackbar('Error', 'Failed to take picture! File was empty!');
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
            bottom: context.height / 30,
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.only(left: 10),
              minimumSize: Size.square(30),
              backgroundColor: Colors.transparent,
            ),
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
            bottom: context.height / 30,
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.all(0),
              minimumSize: Size.square(30),
              backgroundColor: Colors.transparent,
            ),
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
          bottom: context.height / 30,
        ),
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.only(right: 10),
            minimumSize: Size.square(30),
            backgroundColor: Colors.transparent,
          ),
          onPressed: () async {
            if (!this.hasContext) return;

            HapticFeedback.lightImpact();
            BlueBubblesTextField.of(context)!.cameraIndex = (BlueBubblesTextField.of(context)!.cameraIndex - 1).abs();
            await BlueBubblesTextField.of(context)!.initializeCameraController();
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
