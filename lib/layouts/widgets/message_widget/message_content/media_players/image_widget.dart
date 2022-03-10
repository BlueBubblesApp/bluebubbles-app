import 'dart:isolate';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageWidgetController extends GetxController {
  bool navigated = false;
  bool visible = true;
  final Rxn<Uint8List> data = Rxn<Uint8List>();
  final PlatformFile file;
  final Attachment attachment;
  final BuildContext context;
  ImageWidgetController({
    required this.file,
    required this.attachment,
    required this.context,
  });

  @override
  void onInit() {
    if (ModalRoute.of(context)?.animation != null) {
      if (ModalRoute.of(context)?.animation?.status != AnimationStatus.completed) {
        late final AnimationStatusListener listener;
        listener = (AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            initBytes();
            ModalRoute.of(context)?.animation?.removeStatusListener(listener);
          }
        };
        ModalRoute.of(context)?.animation?.addStatusListener(listener);
      } else {
        initBytes();
      }
    } else {
      initBytes();
    }
    super.onInit();
  }

  void initBytes({bool runForcefully = false}) async {
    // initGate prevents this from running more than once
    // Especially if the compression takes a while
    if (!runForcefully && data.value != null) return;

    // Try to get the image data from the "cache"
    Uint8List? tmpData = ChatManager().activeChat?.getImageData(attachment);
    if (tmpData == null) {
      // If it's an image, compress the image when loading it
      if (kIsWeb || file.path == null) {
        if (attachment.guid != "redacted-mode-demo-attachment") {
          if ((attachment.mimeType?.endsWith("tif") ?? false) || (attachment.mimeType?.endsWith("tiff") ?? false)) {
            final receivePort = ReceivePort();
            await Isolate.spawn(
                unsupportedToPngIsolate, IsolateData(file, receivePort.sendPort));
            // Get the processed image from the isolate.
            final image = await receivePort.first as Uint8List?;
            tmpData = image;
          } else {
            tmpData = file.bytes;
          }
        } else {
          data.value = Uint8List.view((await rootBundle.load(attachment.transferName!)).buffer);
          return;
        }
      } else if (AttachmentHelper.canCompress(attachment) &&
          attachment.guid != "redacted-mode-demo-attachment" &&
          !attachment.guid!.contains("theme-selector")) {
        tmpData = await AttachmentHelper.compressAttachment(attachment, file.path!);
        // All other attachments can be held in memory as bytes
      } else {
        if (attachment.guid == "redacted-mode-demo-attachment" || attachment.guid!.contains("theme-selector")) {
          data.value = (await rootBundle.load(file.path!)).buffer.asUint8List();
          return;
        }
        tmpData = await File(file.path!).readAsBytes();
      }

      if (tmpData == null || !ChatManager().hasActiveChat) return;
      ChatManager().activeChat!.saveImageData(tmpData, attachment);
      if (!(attachment.mimeType?.endsWith("heic") ?? false) && !(attachment.mimeType?.endsWith("heif") ?? false)) {
        await precacheImage(MemoryImage(tmpData), context, size: attachment.width == null ? null : Size.fromWidth(attachment.width! / 2));
      }
    }
    data.value = tmpData;
  }
}

class ImageWidget extends StatelessWidget {
  final PlatformFile file;
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
            ChatManager().activeChat?.clearImageData(controller.attachment);
            controller.update();
          } else if (!controller.visible) {
            controller.visible = true;
            controller.initBytes(runForcefully: true);
          }
        },
        child: GestureDetector(
          child: buildSwitcher(context, controller),
          onTap: () async {
            controller.navigated = true;
            ChatController? currentChat = ChatManager().activeChat;
            await Navigator.of(Get.context!).push(
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
    );
  }

  Widget buildSwitcher(BuildContext context, ImageWidgetController controller) => AnimatedSwitcher(
      duration: Duration(milliseconds: 150),
      child: Obx(
        () => controller.data.value != null
            ? Container(
              width: controller.attachment.guid == "redacted-mode-demo-attachment" ? controller.attachment.width!.toDouble() : null,
              height: controller.attachment.guid == "redacted-mode-demo-attachment" ? controller.attachment.height!.toDouble() : null,
              child: Image.memory(
                controller.data.value!,
                // prevents the image widget from "refreshing" when the provider changes
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                cacheWidth: (controller.attachment.width != null ? (controller.attachment.width! * Get.pixelRatio).round().abs() : null).nonZero,
                cacheHeight: (controller.attachment.height != null ? (controller.attachment.height! * Get.pixelRatio).round().abs() : null).nonZero,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  return Stack(children: [
                    buildPlaceHolder(context, controller, isLoaded: wasSynchronouslyLoaded),
                    AnimatedOpacity(
                      opacity: (frame == null &&
                          controller.attachment.guid != "redacted-mode-demo-attachment" &&
                          !controller.attachment.guid!.contains("theme-selector"))
                          ? 0
                          : 1,
                      child: child,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                  ]);
                },
              ),
            )
            : buildPlaceHolder(context, controller),
      ));

  Widget buildPlaceHolder(BuildContext context, ImageWidgetController controller, {bool isLoaded = false}) {
    Widget empty = Container(height: 0, width: 0);

    // Handle the cases when the image is done loading
    if (isLoaded) {
      // If we have controller.data.value and the image has a valid size, return an empty container (no placeholder)
      if (controller.data.value != null && controller.data.value!.isNotEmpty) {
        return empty;
      } else {
        // If we don't have controller.data.value, show an invalid image placeholder
        return buildImagePlaceholder(
            context,
            controller.attachment,
            Center(
                child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text("Something went wrong! Tap to display in fullscreen", textAlign: TextAlign.center),
            )));
      }
    }

    // If it's not loaded, we are in progress
    return buildImagePlaceholder(context, controller.attachment,
        controller.attachment.guid != "redacted-mode-demo-attachment"
            ? Center(child: buildProgressIndicator(context)) : Container());
  }
}

extension NonZero on int? {
  int? get nonZero => (this ?? 0) == 0 ? null : this;
}
