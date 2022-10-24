import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/conversation_view/text_field/attachments/picker/attachment_picked.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/models/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class TextFieldAttachmentPicker extends StatefulWidget {
  TextFieldAttachmentPicker({
    Key? key,
    required this.visible,
    required this.onAddAttachment,
  }) : super(key: key);
  final bool visible;
  final Function(PlatformFile?) onAddAttachment;

  @override
  State<TextFieldAttachmentPicker> createState() => _TextFieldAttachmentPickerState();
}

class _TextFieldAttachmentPickerState extends State<TextFieldAttachmentPicker> {
  List<AssetEntity> _images = <AssetEntity>[];

  @override
  void initState() {
    super.initState();
    getAttachments();

    eventDispatcher.stream.listen((event) {
      if (!mounted) return;

      if (event.item1 == "add-attachment") {
        PlatformFile file = PlatformFile.fromMap(event.item2);
        widget.onAddAttachment(file);
      }
    });
  }

  Future<void> getAttachments() async {
    if (!mounted) return;
    if (kIsDesktop || kIsWeb) return;
    List<AssetPathEntity> list = await PhotoManager.getAssetPathList(onlyAll: true);
    if (list.isNotEmpty) {
      List<AssetEntity> images = await list.first.getAssetListRange(start: 0, end: 24);
      _images = images;
      if (DateTime.now().toLocal().isWithin(images.first.modifiedDateTime, minutes: 2)) {
        dynamic file = await images.first.file;
        eventDispatcher.emit('add-custom-smartreply', {
          "path": file.path,
          "name": file.path.split('/').last,
          "size": file.lengthSync(),
          "bytes": file.readAsBytesSync(),
        });
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> openFullCamera({String type = 'camera'}) async {
    bool camera = await Permission.camera.isGranted;
    if (!camera) {
      bool granted = (await Permission.camera.request()) == PermissionStatus.granted;
      if (!granted) {
        showSnackbar(
            "Error",
            "Camera was denied"
        );
        return;
      }
    }

    late final XFile? file;
    if (type == 'camera') {
      file = await ImagePicker().pickImage(source: ImageSource.camera);
    } else {
      file = await ImagePicker().pickVideo(source: ImageSource.camera);
    }
    if (file != null) {
      widget.onAddAttachment(PlatformFile(
        path: file.path,
        name: file.path.split('/').last,
        size: await file.length(),
        bytes: await file.readAsBytes(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: widget.visible
          ? SizedBox(
              child: RefreshIndicator(
                onRefresh: () async {
                  getAttachments();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 300,
                    child: CustomScrollView(
                      physics: ThemeSwitcher.getScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(left: 5, right: 5, top: 5, bottom: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: context.theme.colorScheme.properSurface,
                                      ),
                                      onPressed: () async {
                                        final res = await FilePicker.platform.pickFiles(withReadStream: true, allowMultiple: true);
                                        if (res == null || res.files.isEmpty) return;

                                        for (pf.PlatformFile file in res.files) {
                                          if (file.size / 1024000 > 100) {
                                            showSnackbar("Error", "This file is over 100 MB! Please compress it before sending.");
                                            continue;
                                          }
                                          widget.onAddAttachment(PlatformFile(
                                            path: file.path,
                                            name: file.name,
                                            bytes: await readByteStream(file.readStream!),
                                            size: file.size
                                          ));
                                        }
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              ss.settings.skin.value == Skins.iOS ? CupertinoIcons.folder_open : Icons.folder_open,
                                              color: context.theme.colorScheme.properOnSurface,
                                            ),
                                          ),
                                          Text(
                                            "Files",
                                            style: TextStyle(
                                              color: context.theme.colorScheme.properOnSurface,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(height: 10),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: context.theme.colorScheme.properSurface,
                                      ),
                                      onPressed: () async {
                                        await Share.location(ChatManager().activeChat!.chat);
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              ss.settings.skin.value == Skins.iOS ? CupertinoIcons.location : Icons.location_on,
                                              color: context.theme.colorScheme.properOnSurface,
                                            ),
                                          ),
                                          Text(
                                            "Location",
                                            style: TextStyle(
                                              color: context.theme.colorScheme.properOnSurface,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(left: 5, right: 10, top: 5, bottom: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: context.theme.colorScheme.properSurface,
                                      ),
                                      onPressed: () async {
                                        openFullCamera();
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              ss.settings.skin.value == Skins.iOS ? CupertinoIcons.camera : Icons.photo_camera,
                                              color: context.theme.colorScheme.properOnSurface,
                                            ),
                                          ),
                                          Text(
                                            "Camera",
                                            style: TextStyle(
                                              color: context.theme.colorScheme.properOnSurface,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(height: 10),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: context.theme.colorScheme.properSurface,
                                      ),
                                      onPressed: () async {
                                        openFullCamera(type: "video");
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              ss.settings.skin.value == Skins.iOS ? CupertinoIcons.videocam : Icons.videocam,
                                              color: context.theme.colorScheme.properOnSurface,
                                            ),
                                          ),
                                          Text(
                                            "Video",
                                            style: TextStyle(
                                              color: context.theme.colorScheme.properOnSurface,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              AssetEntity element = _images[index];
                              return AttachmentPicked(
                                key: Key("attachmentPicked${_images[index].id}"),
                                data: element,
                                onTap: () async {
                                  dynamic file = await element.file;
                                  widget.onAddAttachment(PlatformFile(
                                    path: file.path,
                                    name: file.path.split('/').last,
                                    size: file.lengthSync(),
                                    bytes: file.readAsBytesSync(),
                                  ));
                                },
                              );
                            },
                            childCount: _images.length,
                          ),
                        ),
                      ],
                    ),
                  )
                ),
              ),
              height: 300,
            )
          : Container(),
    );
  }
}
