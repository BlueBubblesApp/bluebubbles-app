import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/helpers/attachment_sender.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class BlueBubblesTextField extends StatefulWidget {
  final Chat chat;
  final Function customSend;
  final List<File> existingAttachments;
  final String existingText;
  BlueBubblesTextField({
    Key key,
    this.chat,
    this.customSend,
    this.existingAttachments,
    this.existingText,
  }) : super(key: key);

  @override
  _BlueBubblesTextFieldState createState() => _BlueBubblesTextFieldState();
}

class _BlueBubblesTextFieldState extends State<BlueBubblesTextField> {
  TextEditingController _controller;
  FocusNode _focusNode;
  List<AssetEntity> _images = <AssetEntity>[];
  bool showImagePicker = false;
  List<File> pickedImages = <File>[];
  List<Widget> _imageWidgets = <Widget>[];

  @override
  void initState() {
    // TODO: implement initState
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
    // TODO: implement dispose
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
                      width: 100,
                      height: 100,
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
                            debugPrint(pickedImages.toString());
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
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 30,
          sigmaY: 30,
        ),
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.all(5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
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
                            : Image.file(
                                pickedImages[index],
                                height: 100,
                                fit: BoxFit.fitHeight,
                              ),
                        Positioned.fill(
                            child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              File image = pickedImages[index];
                              for (int i = 0; i < pickedImages.length; i++) {
                                if (pickedImages[i].path == image.path) {
                                  pickedImages.removeAt(i);
                                  setState(() {});
                                  return;
                                }
                              }
                            },
                          ),
                        ))
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Flexible(
                    child: GestureDetector(
                      onTap: handleOpenImagePicker,
                      child: Icon(
                        Icons.camera_alt,
                        color: HexColor('8e8e8e'),
                        size: 30,
                      ),
                    ),
                  ),
                  Spacer(flex: 1),
                  Flexible(
                    flex: 15,
                    child: Container(
                      child: Stack(
                        alignment: AlignmentDirectional.centerEnd,
                        children: <Widget>[
                          CupertinoTextField(
                            // autofocus: true,
                            focusNode: _focusNode,
                            controller: _controller,
                            scrollPhysics: BouncingScrollPhysics(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            placeholder: "BlueBubbles",
                            padding: EdgeInsets.only(
                                left: 10, right: 40, top: 10, bottom: 10),
                            placeholderStyle: TextStyle(
                              color: Color.fromARGB(255, 100, 100, 100),
                            ),
                            autofocus: true,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border.all(
                                color: HexColor('302f32'),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          ButtonTheme(
                            minWidth: 30,
                            height: 30,
                            child: RaisedButton(
                              padding: EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              color: Colors.blue,
                              onPressed: () {
                                if (widget.customSend != null) {
                                  widget.customSend(
                                      pickedImages, _controller.text);
                                } else {
                                  if (pickedImages.length > 0) {
                                    for (int i = 0;
                                        i < pickedImages.length;
                                        i++) {
                                      new AttachmentSender(
                                        pickedImages[i],
                                        widget.chat,
                                        i == pickedImages.length - 1
                                            ? _controller.text
                                            : "",
                                      );
                                    }
                                  } else {
                                    SocketManager().sendMessage(
                                        widget.chat, _controller.text);
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              showImagePicker
                  ? SizedBox(
                      child: GridView.builder(
                        physics: AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageWidgets.length + 2,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == _imageWidgets.length) {
                            return RaisedButton(
                              onPressed: () async {
                                PickedFile pickedImage = await ImagePicker()
                                    .getImage(source: ImageSource.gallery);
                                File image = File(pickedImage.path);
                                pickedImages.add(image);
                                setState(() {});
                              },
                              color: HexColor('26262a'),
                              child: Text(
                                "Pick Image",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          } else if (index == _imageWidgets.length + 1) {
                            return RaisedButton(
                              onPressed: () async {
                                PickedFile pickedImage = await ImagePicker()
                                    .getVideo(source: ImageSource.gallery);
                                File image = File(pickedImage.path);
                                pickedImages.add(image);
                                setState(() {});
                              },
                              color: HexColor('26262a'),
                              child: Text(
                                "Pick Video",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return _imageWidgets[index];
                        },
                      ),
                      height: 200,
                      // width: MediaQuery.of(context).size.width,
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
