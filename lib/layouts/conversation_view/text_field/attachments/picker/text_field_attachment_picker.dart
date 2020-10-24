import 'dart:io';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/layouts/conversation_view/camera_widget.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/attachment_picked.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class TextFieldAttachmentPicker extends StatefulWidget {
  TextFieldAttachmentPicker({
    Key key,
    @required this.visible,
    @required this.onAddAttachment,
    @required this.chat,
  }) : super(key: key);
  final bool visible;
  final Function(File) onAddAttachment;
  final Chat chat;

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
    getAttachments();
  }

  Future<void> getAttachments() async {
    if (await PhotoManager.requestPermission()) {
      List<AssetPathEntity> list =
          await PhotoManager.getAssetPathList(onlyAll: true);
      List<AssetEntity> images =
          await list.first.getAssetListRange(start: 0, end: 60);
      _images = images;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Duration(milliseconds: 100),
      vsync: this,
      curve: Curves.easeInOut,
      child: widget.visible
          ? SizedBox(
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                scrollDirection: Axis.horizontal,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          SizedBox(
                            width: 85,
                            height: 80,
                            child: RaisedButton(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onPressed: () async {
                                String res = await MethodChannelInterface()
                                    .invokeMethod("pick-image");
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
                                      Icons.photo_library,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText1
                                          .color,
                                    ),
                                  ),
                                  Text(
                                    "Images",
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
                            width: 85,
                            height: 80,
                            child: RaisedButton(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onPressed: () async {
                                String res = await MethodChannelInterface()
                                    .invokeMethod("pick-video");
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
                                    "Videos",
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
                            width: 85,
                            height: 80,
                            child: RaisedButton(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
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
                                          Share.location(widget.chat);
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
                          key: Key(index.toString()),
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
