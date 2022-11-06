import 'dart:async';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_picker_file.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/models/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class AttachmentPicker extends StatefulWidget {
  AttachmentPicker({
    Key? key,
    required this.controller,
  }) : super(key: key);
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

    eventDispatcher.stream.listen((event) {
      if (event.item1 == "add-attachment") {
        PlatformFile file = PlatformFile.fromMap(event.item2);
        controller.pickedAttachments.add(file);
      }
    });
  }

  Future<void> getAttachments() async {
    if (kIsDesktop || kIsWeb) return;
    // wait for opening animation to complete
    await Future.delayed(Duration(milliseconds: 250));
    List<AssetPathEntity> list = await PhotoManager.getAssetPathList(onlyAll: true);
    if (list.isNotEmpty) {
      _images = await list.first.getAssetListRange(start: 0, end: 24);
      // see if there is a recent attachment
      if (DateTime.now().toLocal().isWithin(_images.first.modifiedDateTime, minutes: 2)) {
        final file = await _images.first.file;
        if (file == null) return;
        eventDispatcher.emit('add-custom-smartreply', {
          "path": file.path,
          "name": file.path.split('/').last,
          "size": await file.length(),
          "bytes": await file.readAsBytes(),
        });
      }
    }

    if (mounted) setState(() {});
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
          return CupertinoIcons.folder_open;
        case 1:
          return CupertinoIcons.location;
        case 2:
          return CupertinoIcons.camera;
        case 3:
          return CupertinoIcons.videocam;
      }
    } else {
      switch (index) {
        case 0:
          return Icons.folder_open_outlined;
        case 1:
          return Icons.location_on_outlined;
        case 2:
          return Icons.photo_camera_outlined;
        case 3:
          return Icons.videocam_outlined;
      }
    }
    return Icons.abc;
  }

  String getText(int index) {
    switch (index) {
      case 0:
        return "Files";
      case 1:
        return "Location";
      case 2:
        return "Camera";
      case 3:
        return "Video";
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
            physics: AlwaysScrollableScrollPhysics(),
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
                                case 1:
                                  await Share.location(cm.activeChat!.chat);
                                  return;
                                case 2:
                                  openFullCamera();
                                  return;
                                case 3:
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
