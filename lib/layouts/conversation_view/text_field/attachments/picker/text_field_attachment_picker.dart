import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/attachment_picked.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:universal_io/io.dart';

class TextFieldAttachmentPicker extends StatefulWidget {
  TextFieldAttachmentPicker({
    Key? key,
    required this.visible,
    required this.onAddAttachment,
  }) : super(key: key);
  final bool visible;
  final Function(PlatformFile?) onAddAttachment;

  @override
  _TextFieldAttachmentPickerState createState() => _TextFieldAttachmentPickerState();
}

class _TextFieldAttachmentPickerState extends State<TextFieldAttachmentPicker> {
  List<AssetEntity> _images = <AssetEntity>[];

  @override
  void initState() {
    super.initState();
    getAttachments();
    // If the app is reopened, then update the attachments
    LifeCycleManager().stream.listen((event) async {
      if (event) getAttachments();
    });

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!mounted) return;
      if (!event.containsKey("type")) return;

      if (event["type"] == "add-attachment") {
        PlatformFile file = PlatformFile.fromMap(event['data']);
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
        EventDispatcher().emit('add-custom-smartreply', {
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

    // Create a file that the camera can write to
    String appDocPath = SettingsManager().appDocDir.path;
    String ext = (type == 'video') ? ".mp4" : ".png";
    File file = File("$appDocPath/attachments/" + randomString(16) + ext);
    await file.create(recursive: true);

    // Take the picture after opening the camera
    await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": type});

    // If we don't get data back, return outta here
    if (!file.existsSync()) return;
    if (file.statSync().size == 0) {
      file.deleteSync();
      return;
    }

    widget.onAddAttachment(PlatformFile(
      path: file.path,
      name: file.path.split('/').last,
      size: file.lengthSync(),
      bytes: file.readAsBytesSync(),
    ));
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
                                        primary: Theme.of(context).colorScheme.secondary,
                                      ),
                                      onPressed: () async {
                                        final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
                                        if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                                        for (pf.PlatformFile file in res.files) {
                                          widget.onAddAttachment(PlatformFile(
                                            path: file.path,
                                            name: file.name,
                                            bytes: file.bytes,
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
                                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.folder_open : Icons.folder_open,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Files",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
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
                                        primary: Theme.of(context).colorScheme.secondary,
                                      ),
                                      onPressed: () async {
                                        showDialog(
                                          context: context,
                                          builder: (buildContext) => AlertDialog(
                                            backgroundColor: Theme.of(context).colorScheme.secondary,
                                            title: Text(
                                              "Send Current Location?",
                                              style: Theme.of(context).textTheme.headline1,
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.blue[600],
                                                ),
                                                child: Text(
                                                  "Send",
                                                  style: Theme.of(context).textTheme.bodyText1,
                                                ),
                                                onPressed: () async {
                                                  Share.location(ChatManager().activeChat!.chat);
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: Text(
                                                  "Cancel",
                                                  style: Theme.of(context).textTheme.bodyText1,
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.location : Icons.location_on,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Location",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
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
                                        primary: Theme.of(context).colorScheme.secondary,
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
                                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.camera : Icons.photo_camera,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Camera",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
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
                                        primary: Theme.of(context).colorScheme.secondary,
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
                                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.videocam : Icons.videocam,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Video",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
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
                                key: Key("attachmentPicked" + _images[index].id),
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
