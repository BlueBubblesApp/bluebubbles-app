import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_picker_file.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hand_signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class AttachmentPicker extends StatefulWidget {
  AttachmentPicker({
    super.key,
    required this.controller,
  });
  final ConversationViewController controller;

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends OptimizedState<AttachmentPicker> {
  List<AssetEntity> _images = <AssetEntity>[];

  ConversationViewController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    getAttachments();
  }

  Future<void> getAttachments() async {
    if (kIsDesktop || kIsWeb) return;
    // wait for opening animation to complete
    await Future.delayed(const Duration(milliseconds: 250));
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      showSnackbar("Error", "Storage permission not granted!");
      return;
    }
    List<AssetPathEntity> list = await PhotoManager.getAssetPathList(onlyAll: true);
    if (list.isNotEmpty) {
      _images = await list.first.getAssetListRange(start: 0, end: 24);
      // see if there is a recent attachment
      if (DateTime.now().toLocal().isWithin(_images.first.modifiedDateTime, minutes: 2)) {
        final file = await _images.first.file;
        if (file != null) {
          eventDispatcher.emit('add-custom-smartreply', PlatformFile(
            path: file.path,
            name: file.path.split('/').last,
            size: await file.length(),
            bytes: await file.readAsBytes(),
          ));
        }
      }
    }
    setState(() {});
  }

  Future<void> openFullCamera({String type = 'camera'}) async {
    bool granted = (await Permission.camera.request()).isGranted;
    if (!granted) {
      showSnackbar(
        "Error",
        "Camera access was denied!"
      );
      return;
    }

    late final XFile? file;
    if (type == 'camera') {
      file = await ImagePicker().pickImage(source: ImageSource.camera);
    } else {
      file = await ImagePicker().pickVideo(source: ImageSource.camera);
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

  IconData getIcon(int index) {
    if (iOS) {
      switch (index) {
        case 0:
          return CupertinoIcons.camera;
        case 1:
          return CupertinoIcons.videocam;
        case 2:
          return CupertinoIcons.folder_open;
        case 3:
          return CupertinoIcons.location;
        case 4:
          return CupertinoIcons.calendar_today;
        case 5:
          return CupertinoIcons.pencil_outline;
      }
    } else {
      switch (index) {
        case 0:
          return Icons.photo_camera_outlined;
        case 1:
          return Icons.videocam_outlined;
        case 2:
          return Icons.folder_open_outlined;
        case 3:
          return Icons.location_on_outlined;
        case 4:
          return Icons.schedule;
        case 5:
          return Icons.draw;
      }
    }
    return Icons.abc;
  }

  String getText(int index) {
    switch (index) {
      case 0:
        return "Photo";
      case 1:
        return "Video";
      case 2:
        return "Files";
      case 3:
        return "Location";
      case 4:
        return "Schedule";
      case 5:
        return "Handwritten";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: RefreshIndicator(
        onRefresh: () async {
          getAttachments();
        },
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (OverscrollIndicatorNotification overscroll) {
            // prevent stretchy effect
            overscroll.disallowIndicator();
            return true;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: CustomScrollView(
                  physics: ThemeSwitcher.getScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  slivers: <Widget>[
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                            ),
                            onPressed: () async {
                              switch (index) {
                                case 0:
                                  openFullCamera();
                                  return;
                                case 1:
                                  openFullCamera(type: "video");
                                  return;
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  getIcon(index),
                                  color: context.theme.colorScheme.properOnSurface,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  getText(index),
                                  style: context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: 2,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(left: 5, right: 5)),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 2/3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        index = index + 2;
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            backgroundColor: context.theme.colorScheme.properSurface,
                          ),
                          onPressed: () async {
                            switch (index) {
                              case 2:
                                final res = await FilePicker.platform.pickFiles(withReadStream: true, allowMultiple: true);
                                if (res == null || res.files.isEmpty) return;

                                for (pf.PlatformFile file in res.files) {
                                  if (file.size / 1024000 > 1000) {
                                    showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                                    continue;
                                  }
                                  controller.pickedAttachments.add(PlatformFile(
                                      path: file.path,
                                      name: file.name,
                                      bytes: await readByteStream(file.readStream!),
                                      size: file.size
                                  ));
                                }
                                return;
                              case 3:
                                await Share.location(cm.activeChat!.chat);
                                return;
                              case 4:
                                if (controller.pickedAttachments.isNotEmpty) {
                                  return showSnackbar("Error", "Remove all attachments before scheduling!");
                                } else if (controller.replyToMessage != null || controller.subjectTextController.text.isNotEmpty) {
                                  return showSnackbar("Error", "Private API features are not supported when scheduling!");
                                }
                                final date = await showTimeframePicker("Pick date and time", context, presetsAhead: true);
                                if (date != null && date.isAfter(DateTime.now())) {
                                  controller.scheduledDate.value = date;
                                }
                                return;
                              case 5:
                                Color selectedColor = context.theme.colorScheme.bubble(context, controller.chat.isIMessage);
                                final result = (await ColorPicker(
                                  color: selectedColor,
                                  onColorChanged: (Color newColor) {
                                    selectedColor = newColor;
                                  },
                                  title: Text(
                                    "Select Color",
                                    style: context.theme.textTheme.titleLarge,
                                  ),
                                  width: 40,
                                  height: 40,
                                  spacing: 0,
                                  runSpacing: 0,
                                  borderRadius: 0,
                                  wheelDiameter: 165,
                                  enableOpacity: false,
                                  showColorCode: true,
                                  colorCodeHasColor: true,
                                  pickersEnabled: <ColorPickerType, bool>{
                                    ColorPickerType.wheel: true,
                                  },
                                  copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                                    parseShortHexCode: true,
                                  ),
                                  actionButtons: const ColorPickerActionButtons(
                                    dialogActionButtons: true,
                                  ),
                                ).showPickerDialog(
                                  context,
                                  barrierDismissible: false,
                                  constraints: BoxConstraints(
                                      minHeight: 480, minWidth: ns.width(context) - 70, maxWidth: ns.width(context) - 70),
                                ));
                                if (result) {
                                  final control = HandSignatureControl();
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text(
                                          "Draw Handwritten Message",
                                          style: context.theme.textTheme.titleLarge,
                                        ),
                                        content: AspectRatio(
                                          aspectRatio: 1,
                                          child: Container(
                                            constraints: const BoxConstraints.expand(),
                                            child: HandSignature(
                                              control: control,
                                              color: selectedColor,
                                              width: 1.0,
                                              maxWidth: 10.0,
                                              type: SignatureDrawType.shape,
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              final bytes = await control.toImage(height: 512, fit: false);
                                              if (bytes != null) {
                                                final uint8 = bytes.buffer.asUint8List();
                                                controller.pickedAttachments.add(PlatformFile(
                                                  path: null,
                                                  name: "handwritten-${randomString(3)}.png",
                                                  bytes: uint8,
                                                  size: uint8.lengthInBytes,
                                                ));
                                              }
                                            },
                                          ),
                                        ],
                                        backgroundColor: context.theme.colorScheme.properSurface,
                                      );
                                    },
                                  );
                                }
                                return;
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                getIcon(index),
                                color: context.theme.colorScheme.properOnSurface,
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                  getText(index),
                                  style: context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: 4,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(left: 5, right: 5)),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                          final element = _images[index];
                          return AttachmentPickerFile(
                            key: Key("AttachmentPickerFile-${element.id}"),
                            data: element,
                            controller: controller,
                            onTap: () async {
                              final file = await element.file;
                              if (file == null) return;
                              if ((await file.length()) / 1024000 > 1000) {
                                showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                                return;
                              }
                              if (controller.pickedAttachments.firstWhereOrNull((e) => e.path == file.path) != null) {
                                controller.pickedAttachments.removeWhere((e) => e.path == file.path);
                              } else {
                                controller.pickedAttachments.add(PlatformFile(
                                  path: file.path,
                                  name: file.path.split('/').last,
                                  size: await file.length(),
                                  bytes: await file.readAsBytes(),
                                ));
                              }
                            },
                          );
                        },
                        childCount: _images.length,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ),
        ),
      ),
    );
  }
}
