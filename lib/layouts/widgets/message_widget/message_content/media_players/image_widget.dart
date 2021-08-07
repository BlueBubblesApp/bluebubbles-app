import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageWidgetController extends GetxController {
  bool navigated = false;
  bool visible = true;
  final Rxn<Uint8List> data = Rxn<Uint8List>();
  final File file;
  final Attachment attachment;
  final BuildContext context;
  ImageWidgetController({
    required this.file,
    required this.attachment,
    required this.context,
  });

  @override
  void onInit() {
    initBytes();
    super.onInit();
  }

  void initBytes({bool runForcefully = false}) async {
    // initGate prevents this from running more than once
    // Especially if the compression takes a while
    if (!runForcefully && data.value != null) return;

    // Try to get the image data from the "cache"
    data.value = CurrentChat.of(context)?.getImageData(attachment);
    if (data.value == null) {
      // If it's an image, compress the image when loading it
      if (AttachmentHelper.canCompress(attachment) &&
          attachment.guid != "redacted-mode-demo-attachment" &&
          !attachment.guid!.contains("theme-selector")) {
        data.value = await AttachmentHelper.compressAttachment(attachment, file.absolute.path);
        // All other attachments can be held in memory as bytes
      } else {
        if (attachment.guid == "redacted-mode-demo-attachment" ||
            attachment.guid!.contains("theme-selector")) {
          data.value = (await rootBundle.load(file.path)).buffer.asUint8List();
          return;
        }
        data.value = await file.readAsBytes();
      }

      if (data.value == null || CurrentChat.of(context) == null) return;
      CurrentChat.of(context)?.saveImageData(data.value!, attachment);
    }
  }
}

class ImageWidget extends StatelessWidget {
  final File file;
  final Attachment attachment;
  ImageWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImageWidgetController>(
      global: false,
      init: ImageWidgetController(
        file: file,
        attachment: attachment,
        context: context,
      ),
      builder: (controller) => VisibilityDetector(
        key: Key(controller.attachment.guid!),
        onVisibilityChanged: (info) {
          if (!SettingsManager().settings.lowMemoryMode.value) return;
          if (info.visibleFraction == 0 && controller.visible && !controller.navigated) {
            controller.visible = false;
            CurrentChat.of(context)?.clearImageData(controller.attachment);
            controller.update();
          } else if (!controller.visible) {
            controller.visible = true;
            controller.initBytes(runForcefully: true);
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            child: buildSwitcher(context, controller),
            onTap: () async {
              controller.navigated = true;
              CurrentChat? currentChat = CurrentChat.of(context);
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AttachmentFullscreenViewer(
                    currentChat: currentChat,
                    attachment: controller.attachment,
                    showInteractions: true,
                  ),
                ),
              );
              controller.navigated = false;
            },
          ),
        ),
      ),
    );
  }

  Widget buildSwitcher(BuildContext context, ImageWidgetController controller) => AnimatedSwitcher(
    duration: Duration(milliseconds: 150),
    child: Obx(() => controller.data.value != null
        ? Image.memory(
            controller.data.value!,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              return Stack(children: [
                buildPlaceHolder(context, controller, isLoaded: frame != null || wasSynchronouslyLoaded),
                AnimatedOpacity(
                  opacity: (frame == null &&
                      controller.attachment.guid != "redacted-mode-demo-attachment" &&
                      controller.attachment.guid!.contains("theme-selector"))
                      ? 0
                      : 1,
                  child: child,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                )
        ]);
      },
    )
        : buildPlaceHolder(context, controller),
  ));

  Widget buildPlaceHolder(BuildContext context, ImageWidgetController controller, {bool isLoaded = false}) {
    Widget empty = Container(height: 0, width: 0);

    // Handle the cases when the image is done loading
    if (isLoaded) {
      // If we have controller.data.value and the image has a valid size, return an empty container (no placeholder)
      if (controller.data.value != null && controller.data.value!.length > 0 && controller.attachment.hasValidSize) {
        return empty;
      } else if (controller.data.value != null && controller.data.value!.length > 0) {
        // If we have controller.data.value, but _not_ a valid size, return an empty image placeholder
        return buildImagePlaceholder(context, controller.attachment, Center(child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("Something went wrong, tap here to display in fullscreen"),
        )));
      } else {
        // If we don't have controller.data.value, show an invalid image placeholder
        return buildImagePlaceholder(context, controller.attachment, Center(child: Text("Invalid Image")));
      }
    }

    // If it's not loaded, we are in progress
    return buildImagePlaceholder(context, controller.attachment, Center(child: buildProgressIndicator(context)));
  }
}
