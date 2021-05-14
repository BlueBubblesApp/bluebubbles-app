import 'dart:io';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/layouts/conversation_view/camera_widget.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/attachment_picked.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class TextFieldAttachmentPicker extends StatefulWidget {
  TextFieldAttachmentPicker({
    Key key,
    @required this.visible,
    @required this.onAddAttachment,
  }) : super(key: key);
  final bool visible;
  final Function(File) onAddAttachment;

  @override
  _TextFieldAttachmentPickerState createState() =>
      _TextFieldAttachmentPickerState();
}

class _TextFieldAttachmentPickerState extends State<TextFieldAttachmentPicker>
    with SingleTickerProviderStateMixin {
  List<AssetEntity> _images = <AssetEntity>[];
  @override
  void initState() {
    super.initState();
    // If the app is reopened, then update the attachments
    LifeCycleManager().stream.listen((event) async {
      if (event && widget.visible) getAttachments();
    });
  }

  Future<void> getAttachments() async {
    if (!this.mounted) return;
    List<AssetPathEntity> list =
        await PhotoManager.getAssetPathList(onlyAll: true);
    List<AssetEntity> images =
        await list.first.getAssetListRange(start: 0, end: 60);
    _images = images;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visible && _images.isEmpty) {
      getAttachments();
    }
    return AnimatedSize(
      duration: Duration(milliseconds: 100),
      vsync: this,
      curve: Curves.easeInOut,
      child: widget.visible
          ? SizedBox(
              child: CustomScrollView(
                physics: ThemeSwitcher.getScrollPhysics(),
                scrollDirection: Axis.horizontal,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          SizedBox(
                            width: 90,
                            height: 120,
                            child: RaisedButton(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onPressed: () async {
                                await BlueBubblesTextField.of(context)
                                    .cameraController
                                    ?.dispose();
                                String res = await MethodChannelInterface()
                                    .invokeMethod("pick-file");

                                await BlueBubblesTextField.of(context)
                                    .initializeCameraController();
                                if (res == null) return;
                                widget.onAddAttachment(File(res));
                              },
                              color: Theme.of(context).accentColor,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.video_library,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText1
                                          .color,
                                    ),
                                  ),
                                  Text(
                                    "Files",
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText1
                                          .color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            height: 120,
                            child: RaisedButton(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  builder: (buildContext) => AlertDialog(
                                    backgroundColor:
                                        Theme.of(context).accentColor,
                                    title: Text(
                                      "Send Current Location?",
                                      style:
                                          Theme.of(context).textTheme.headline1,
                                    ),
                                    actions: <Widget>[
                                      FlatButton(
                                        color: Colors.blue[600],
                                        child: Text(
                                          "Send",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                        onPressed: () async {
                                          Share.location(
                                              CurrentChat.of(context).chat);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      FlatButton(
                                        child: Text(
                                          "Cancel",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                        color: Colors.red,
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              color: Theme.of(context).accentColor,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText1
                                          .color,
                                    ),
                                  ),
                                  Text(
                                    "Location",
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText1
                                          .color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CameraWidget(
                      addAttachment: (File attachment) {
                        widget.onAddAttachment(attachment);
                      },
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
                            widget.onAddAttachment(await element.file);
                          },
                        );
                      },
                      childCount: _images.length,
                    ),
                  ),
                ],
              ),
              height: 300,
            )
          : Container(),
    );
  }
}
