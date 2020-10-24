import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audio_recorder/audio_recorder.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/layouts/conversation_view/camera_widget.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/text_field_attachment_list.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:file_picker_cross/file_picker_cross.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class BlueBubblesTextField extends StatefulWidget {
  final Chat chat;
  final Function customSend;
  final Function onSend;
  final List<File> existingAttachments;
  final String existingText;
  final Function saveText;
  BlueBubblesTextField({
    Key key,
    this.chat,
    this.customSend,
    this.existingAttachments,
    this.existingText,
    this.onSend,
    this.saveText,
  }) : super(key: key);

  @override
  _BlueBubblesTextFieldState createState() => _BlueBubblesTextFieldState();
}

class _BlueBubblesTextFieldState extends State<BlueBubblesTextField>
    with TickerProviderStateMixin {
  TextEditingController _controller;
  FocusNode _focusNode;
  bool showImagePicker = false;
  List<File> pickedImages = <File>[];
  bool isRecording = false;
  static final GlobalKey<FormFieldState<String>> _searchFormKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    TextFieldData textFieldData;
    if (widget.chat != null) {
      textFieldData = TextFieldBloc().getTextField(widget.chat.guid);
    }
    _controller = textFieldData != null
        ? textFieldData.controller
        : new TextEditingController();
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
    if (widget.chat == null) _controller.dispose();
    String dir = SettingsManager().appDocDir.path;
    Directory tempAssets = Directory("$dir/tempAssets");
    tempAssets.exists().then((value) {
      if (value) {
        tempAssets.delete(recursive: true);
      }
    });
    pickedImages = [];
    super.dispose();
  }

  Future<void> reviewAudio(BuildContext context, File file) async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              backgroundColor: Theme.of(context).accentColor,
              title: new Text("Send it?",
                  style: Theme.of(context).textTheme.headline1),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Review your audio snippet before sending it",
                      style: Theme.of(context).textTheme.subtitle1),
                  Container(height: 10.0),
                  AudioPlayerWiget(file: file)
                ],
              ),
              actions: <Widget>[
                new FlatButton(
                  child: new Text("Send",
                      style: Theme.of(context).textTheme.bodyText1),
                  onPressed: () {
                    OutgoingQueue().add(
                      new QueueItem(
                        event: "send-attachment",
                        item: new AttachmentSender(
                          file,
                          widget.chat,
                          "",
                        ),
                      ),
                    );

                    // Remove the OG alert dialog
                    Navigator.of(context).pop();
                  },
                ),
                new FlatButton(
                    child: new Text("Discard",
                        style: Theme.of(context).textTheme.subtitle1),
                    onPressed: () {
                      file.delete();
                      Navigator.of(context).pop();
                    }),
              ]);
        });
  }

  Future<void> toggleShareMenu() async {
    // If the image picker is already open, close it, and return
    if (!showImagePicker) FocusScope.of(context).requestFocus(new FocusNode());
    showImagePicker = !showImagePicker;
    setState(() {});
  }

  Future<File> _downloadFile(String url, String filename) async {
    HttpClient httpClient = HttpClient();
    var request = await httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    String dir = SettingsManager().appDocDir.path;
    Directory tempAssets = Directory("$dir/tempAssets");
    if (!await tempAssets.exists()) {
      await tempAssets.create();
    }
    File file = new File('$dir/tempAssets/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    IconData rightIcon = Icons.arrow_upward;
    bool canRecord = _controller.text.isEmpty && pickedImages.length == 0;
    if (canRecord) rightIcon = Icons.mic;
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFieldAttachmentList(
                  attachments: pickedImages,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6.0, vertical: 8.0),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: toggleShareMenu,
                          child: Icon(
                            Icons.share,
                            color: HexColor('8e8e8e'),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      fit: FlexFit.loose,
                      child: Container(
                        child: Stack(
                          alignment: AlignmentDirectional.centerEnd,
                          children: <Widget>[
                            AnimatedSize(
                              duration: Duration(milliseconds: 100),
                              vsync: this,
                              curve: Curves.easeInOut,
                              child: CustomCupertinoTextField(
                                onLongPressStart: () {
                                  Feedback.forLongPress(context);
                                },
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                },
                                key: _searchFormKey,
                                onChanged: (String value) {
                                  if (value.isEmpty && this.mounted) {
                                    setState(() {
                                      rightIcon = Icons.mic;
                                    });
                                  } else if (value.isNotEmpty &&
                                      rightIcon == Icons.mic &&
                                      this.mounted) {
                                    setState(() {
                                      rightIcon = Icons.arrow_upward;
                                    });
                                  }
                                },
                                onContentCommited: (String url) async {
                                  debugPrint("got attachment " + url);
                                  List<String> fnParts = url.split("/");
                                  fnParts = (fnParts.length > 2)
                                      ? fnParts.sublist(fnParts.length - 2)
                                      : fnParts.last;
                                  File file = await _downloadFile(
                                      url, fnParts.join("_"));
                                  pickedImages.add(file);
                                  setState(() {});
                                },
                                textCapitalization:
                                    TextCapitalization.sentences,
                                focusNode: _focusNode,
                                autocorrect: true,
                                controller: _controller,
                                scrollPhysics: BouncingScrollPhysics(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .apply(
                                        color: ThemeData
                                                    .estimateBrightnessForColor(
                                                        Theme.of(context)
                                                            .backgroundColor) ==
                                                Brightness.light
                                            ? Colors.black
                                            : Colors.white,
                                        fontSizeDelta: -0.25),
                                keyboardType: TextInputType.multiline,
                                maxLines: 14,
                                minLines: 1,
                                placeholder: "BlueBubbles",
                                padding: EdgeInsets.only(
                                    left: 10, top: 10, right: 40, bottom: 10),
                                placeholderStyle:
                                    Theme.of(context).textTheme.subtitle1,
                                autofocus:
                                    SettingsManager().settings.autoOpenKeyboard,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).backgroundColor,
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
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
                                  onPressed: () async {
                                    if (isRecording) {
                                      HapticFeedback.heavyImpact();
                                      Recording recording =
                                          await AudioRecorder.stop();
                                      setState(() {
                                        isRecording = false;
                                      });
                                      reviewAudio(
                                          context, new File(recording.path));
                                    } else if (canRecord &&
                                        !isRecording &&
                                        await Permission.microphone
                                            .request()
                                            .isGranted) {
                                      HapticFeedback.heavyImpact();
                                      String appDocPath =
                                          SettingsManager().appDocDir.path;
                                      String pathName =
                                          "$appDocPath/attachments/tmp.m4a";
                                      File file = new File(pathName);
                                      if (file.existsSync()) file.deleteSync();
                                      await AudioRecorder.start(
                                          path: pathName,
                                          audioOutputFormat:
                                              AudioOutputFormat.AAC);
                                      setState(() {
                                        isRecording = true;
                                      });
                                    } else if (widget.customSend != null) {
                                      widget.customSend(
                                          pickedImages, _controller.text);
                                    } else {
                                      if (pickedImages.length > 0) {
                                        for (int i = 0;
                                            i < pickedImages.length;
                                            i++) {
                                          OutgoingQueue().add(
                                            new QueueItem(
                                              event: "send-attachment",
                                              item: new AttachmentSender(
                                                pickedImages[i],
                                                widget.chat,
                                                i == pickedImages.length - 1
                                                    ? _controller.text
                                                    : "",
                                              ),
                                            ),
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
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedOpacity(
                                        opacity: _controller.text.isEmpty &&
                                                pickedImages.length == 0
                                            ? 1.0
                                            : 0.0,
                                        duration: Duration(milliseconds: 150),
                                        child: Icon(
                                          Icons.mic,
                                          color: (isRecording)
                                              ? Colors.red
                                              : Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      AnimatedOpacity(
                                          opacity:
                                              (_controller.text.isNotEmpty ||
                                                          pickedImages.length >
                                                              0) &&
                                                      !isRecording
                                                  ? 1.0
                                                  : 0.0,
                                          duration: Duration(milliseconds: 150),
                                          child: Icon(Icons.arrow_upward,
                                              color: Colors.white, size: 20)),
                                    ],
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
                    ),
                  ],
                ),
                TextFieldAttachmentPicker(
                  visible: showImagePicker,
                  onAddAttachment: (File file) {
                    for (File image in pickedImages) {
                      if (image.path == file.path) return;
                    }
                    pickedImages.add(file);
                    setState(() {});
                  },
                  chat: widget.chat,
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
