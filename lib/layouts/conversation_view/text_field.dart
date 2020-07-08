import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/helpers/attachment_sender.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/layouts/conversation_view/camera_widget.dart';
import 'package:bluebubble_messages/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:file_picker_cross/file_picker_cross.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class BlueBubblesTextField extends StatefulWidget {
  final Chat chat;
  final Function customSend;
  final Function onSend;
  final List<File> existingAttachments;
  final String existingText;
  BlueBubblesTextField({
    Key key,
    this.chat,
    this.customSend,
    this.existingAttachments,
    this.existingText,
    this.onSend,
  }) : super(key: key);

  @override
  _BlueBubblesTextFieldState createState() => _BlueBubblesTextFieldState();
}

class _BlueBubblesTextFieldState extends State<BlueBubblesTextField>
    with TickerProviderStateMixin {
  TextEditingController _controller;
  FocusNode _focusNode;
  List<AssetEntity> _images = <AssetEntity>[];
  bool showImagePicker = false;
  List<File> pickedImages = <File>[];
  List<Widget> _imageWidgets = <Widget>[];
  static final GlobalKey<FormFieldState<String>> _searchFormKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.existingText != null) {
      _controller.text = widget.existingText;
    }
    _focusNode = new FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        showImagePicker = false;
        setState(() {});
      }
    });
    if (widget.existingAttachments != null) {
      pickedImages.addAll(widget.existingAttachments);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> handleOpenImagePicker() async {
    FocusScope.of(context).requestFocus(new FocusNode());
    debugPrint("Camera");
    if (await PhotoManager.requestPermission()) {
      List<AssetPathEntity> list =
          await PhotoManager.getAssetPathList(onlyAll: true);
      List<AssetEntity> images =
          await list.first.getAssetListRange(start: 0, end: 60);
      _images = <AssetEntity>[];
      images.forEach((element) {
        _images.add(element);
      });
      showImagePicker = true;
      _imageWidgets = <Widget>[];

      _images.forEach((element) {
        _imageWidgets.add(
          FutureBuilder(
            future: element.thumbDataWithSize(800, 800),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Stack(
                  children: <Widget>[
                    Image.memory(
                      snapshot.data,
                      fit: BoxFit.cover,
                      width: 150,
                      height: 150,
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            File image = await element.file;
                            for (int i = 0; i < pickedImages.length; i++) {
                              if (pickedImages[i].path == image.path) return;
                            }
                            pickedImages.add(image);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return SizedBox(
                  width: 100,
                  height: 100,
                );
              }
            },
          ),
        );
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.all(5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSize(
            vsync: this,
            duration: Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: pickedImages.length > 0 ? 100 : 0,
              ),
              child: GridView.builder(
                itemCount: pickedImages.length,
                scrollDirection: Axis.horizontal,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1),
                itemBuilder: (context, int index) {
                  return Stack(
                    children: <Widget>[
                      mime(pickedImages[index].path).startsWith("video/")
                          ? FutureBuilder(
                              future: VideoThumbnail.thumbnailData(
                                video: pickedImages[index].path,
                                imageFormat: ImageFormat.PNG,
                                maxHeight: 100,
                                quality: 100,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.hasData) {
                                  return Image.memory(snapshot.data);
                                }
                                return SizedBox(
                                  height: 100,
                                  width: 100,
                                  child: CircularProgressIndicator(),
                                );
                              },
                            )
                          : Hero(
                              tag: pickedImages[index].path,
                              child: Image.file(
                                pickedImages[index],
                                height: 100,
                                fit: BoxFit.fitHeight,
                              ),
                            ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => ImageViewer(
                                    file: pickedImages[index],
                                    tag: pickedImages[index].path,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(80),
                            color: Colors.black,
                          ),
                          width: 20,
                          height: 20,
                          child: GestureDetector(
                            onTap: () {
                              File image = pickedImages[index];
                              for (int i = 0; i < pickedImages.length; i++) {
                                if (pickedImages[i].path == image.path) {
                                  pickedImages.removeAt(i);
                                  setState(() {});
                                  return;
                                }
                              }
                            },
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Spacer(
                flex: 1,
              ),
              CupertinoButton(
                onPressed: handleOpenImagePicker,
                child: Icon(
                  Icons.camera_alt,
                  color: HexColor('8e8e8e'),
                  size: 30,
                ),
              ),
              Spacer(
                flex: 1,
              ),
              Container(
                width: MediaQuery.of(context).size.width * 3.5 / 4.5,
                child: Stack(
                  alignment: AlignmentDirectional.centerEnd,
                  children: <Widget>[
                    AnimatedSize(
                      duration: Duration(milliseconds: 100),
                      vsync: this,
                      curve: Curves.easeInOut,
                      child: CupertinoTextField(
                        // autofocus: true,
                        key: _searchFormKey,
                        textCapitalization: TextCapitalization.sentences,
                        focusNode: _focusNode,
                        autocorrect: true,
                        controller: _controller,
                        scrollPhysics: BouncingScrollPhysics(),
                        style: Theme.of(context).textTheme.bodyText1,
                        keyboardType: TextInputType.multiline,
                        maxLines: 14,
                        minLines: 1,
                        placeholder: "BlueBubbles",
                        padding: EdgeInsets.only(
                            left: 10, right: 40, top: 10, bottom: 10),
                        placeholderStyle: Theme.of(context).textTheme.subtitle1,
                        autofocus: true,
                        decoration: BoxDecoration(
                          color: Theme.of(context).backgroundColor,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ButtonTheme(
                        minWidth: 30,
                        height: 30,
                        child: RaisedButton(
                          padding: EdgeInsets.symmetric(
                            horizontal: 0,
                          ),
                          color: Colors.blue,
                          onPressed: () {
                            if (widget.customSend != null) {
                              widget.customSend(pickedImages, _controller.text);
                            } else {
                              if (pickedImages.length > 0) {
                                for (int i = 0; i < pickedImages.length; i++) {
                                  new AttachmentSender(
                                    pickedImages[i],
                                    widget.chat,
                                    i == pickedImages.length - 1
                                        ? _controller.text
                                        : "",
                                  );
                                }
                              } else {
                                ActionHandler.sendMessage(
                                    widget.chat, _controller.text);
                              }

                              if (widget.onSend != null) {
                                widget.onSend(_controller.text);
                              }
                            }

                            _controller.text = "";
                            pickedImages = <File>[];
                            setState(() {});
                          },
                          child: Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Duration(milliseconds: 100),
            vsync: this,
            curve: Curves.easeInOut,
            child: showImagePicker
                ? SizedBox(
                    child: CustomScrollView(
                      physics: AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      scrollDirection: Axis.horizontal,
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                SizedBox(
                                  width: 80,
                                  height: 120,
                                  child: RaisedButton(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    onPressed: () async {
                                      PickedFile pickedImage =
                                          await ImagePicker().getImage(
                                        source: ImageSource.gallery,
                                      );
                                      File image = File(pickedImage.path);
                                      pickedImages.add(image);
                                      setState(() {});
                                    },
                                    color: HexColor('26262a'),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.photo_library,
                                            color: Colors.white,
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
                                  width: 80,
                                  height: 120,
                                  child: RaisedButton(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    onPressed: () async {
                                      FilePickerCross filePicker =
                                          FilePickerCross();
                                      await filePicker.pick();
                                      pickedImages.add(File(filePicker.path));
                                      setState(() {});
                                    },
                                    color: HexColor('26262a'),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.video_library,
                                            color: Colors.white,
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
                                )
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: CameraWidget(
                            addAttachment: (File attachment) {
                              pickedImages.add(attachment);
                              setState(() {});
                            },
                          ),
                        ),
                        SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _imageWidgets[index];
                            },
                            childCount: _imageWidgets.length,
                          ),
                        ),
                      ],
                    ),
                    height: 300,
                  )
                : Container(),
          ),
        ],
      ),
    );
  }
}
