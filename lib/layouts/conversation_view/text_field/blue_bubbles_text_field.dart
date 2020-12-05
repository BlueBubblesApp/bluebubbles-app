import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/text_field_attachment_list.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime_type/mime_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';

class BlueBubblesTextField extends StatefulWidget {
  final List<File> existingAttachments;
  final String existingText;
  final bool isCreator;
  final Future<bool> Function(List<File> attachments, String text) onSend;
  BlueBubblesTextField({
    Key key,
    this.existingAttachments,
    this.existingText,
    @required this.isCreator,
    @required this.onSend,
  }) : super(key: key);
  static BlueBubblesTextFieldState of(BuildContext context) {
    assert(context != null);
    return context.findAncestorStateOfType<BlueBubblesTextFieldState>();
  }

  @override
  BlueBubblesTextFieldState createState() => BlueBubblesTextFieldState();
}

class BlueBubblesTextFieldState extends State<BlueBubblesTextField>
    with TickerProviderStateMixin {
  TextEditingController controller;
  FocusNode focusNode;
  bool showImagePicker = false;
  List<File> pickedImages = <File>[];
  bool isRecording = false;
  TextFieldData textFieldData;
  StreamController _streamController = new StreamController.broadcast();
  CurrentChat safeChat;

  bool selfTyping = false;
  CameraController cameraController;
  int cameraIndex = 0;
  List<CameraDescription> cameras;

  // bool selfTyping = false;

  Stream get stream => _streamController.stream;

  static final GlobalKey<FormFieldState<String>> _searchFormKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();

    if (CurrentChat.of(context)?.chat != null) {
      textFieldData =
          TextFieldBloc().getTextField(CurrentChat.of(context).chat.guid);
    }

    controller = textFieldData != null
        ? textFieldData.controller
        : new TextEditingController();
    controller.addListener(() {
      if (CurrentChat.of(context)?.chat == null) return;
      if (controller.text.length == 0 &&
          pickedImages.length == 0 &&
          selfTyping) {
        selfTyping = false;
        SocketManager().sendMessage("stopped-typing",
            {"chatGuid": CurrentChat.of(context).chat.guid}, (data) => null);
      } else if (!selfTyping &&
          (controller.text.length > 0 || pickedImages.length > 0)) {
        selfTyping = true;
        if (SettingsManager().settings.sendTypingIndicators)
          SocketManager().sendMessage("started-typing",
              {"chatGuid": CurrentChat.of(context).chat.guid}, (data) => null);
      }
      if (this.mounted) setState(() {});
    });

    if (widget.existingText != null) {
      controller.text = widget.existingText;
    }
    focusNode = new FocusNode();
    focusNode.addListener(() {
      if (focusNode.hasFocus && this.mounted) {
        showImagePicker = false;
        setState(() {});
      }
    });
    if (widget.existingAttachments != null) {
      pickedImages.addAll(widget.existingAttachments);
      updateTextFieldAttachments();
    } else if (textFieldData != null) {
      pickedImages.addAll(textFieldData.attachments);
    }
  }

  void updateTextFieldAttachments() {
    if (textFieldData != null) {
      textFieldData.attachments =
          pickedImages.where((element) => mime(element.path) != null).toList();
      _streamController.sink.add(null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    safeChat = CurrentChat.of(context);
  }

  @override
  void dispose() {
    focusNode.dispose();
    _streamController.close();
    cameraController?.dispose();
    if (safeChat?.chat == null) controller.dispose();

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

  void onContentCommit(String url) async {
    debugPrint("got attachment " + url);
    List<String> fnParts = url.split("/");
    fnParts = (fnParts.length > 2)
        ? fnParts.sublist(fnParts.length - 2)
        : fnParts.last;
    File file = await _downloadFile(url, fnParts.join("_"));
    pickedImages.add(file);
    updateTextFieldAttachments();
    if (this.mounted) setState(() {});
  }

  Future<void> reviewAudio(BuildContext originalContext, File file) async {
    showDialog(
      context: originalContext,
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
              AudioPlayerWiget(file: file, context: originalContext)
            ],
          ),
          actions: <Widget>[
            new FlatButton(
                child: new Text("Discard",
                    style: Theme.of(context).textTheme.subtitle1),
                onPressed: () {
                  file.delete();
                  Navigator.of(context).pop();
                }),
            new FlatButton(
              child: new Text(
                "Send",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              onPressed: () async {
                // if (widget.chat == null) return;
                // OutgoingQueue().add(
                //   new QueueItem(
                //     event: "send-attachment",
                //     item: new AttachmentSender(
                //       file,
                //       widget.chat,
                //       "",
                //     ),
                //   ),
                // );
                widget.onSend([file], "");

                // Remove the OG alert dialog
                Navigator.of(originalContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> initializeCameraController() async {
    cameras = await availableCameras();
    cameraController =
        CameraController(cameras[cameraIndex], ResolutionPreset.max);
    await cameraController.initialize();
  }

  Future<void> toggleShareMenu() async {
    // If the image picker is already open, close it, and return
    if (!showImagePicker) FocusScope.of(context).requestFocus(new FocusNode());
    if (!showImagePicker && !(await PhotoManager.requestPermission())) {
      showImagePicker = false;
      if (this.mounted) setState(() {});
      return;
    }
    showImagePicker = !showImagePicker;
    if (this.mounted) setState(() {});
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
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                buildAttachmentList(),
                buildTextFieldAlwaysVisible(),
                buildAttachmentPicker(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAttachmentList() => Padding(
        padding: const EdgeInsets.only(left: 50.0),
        child: TextFieldAttachmentList(
          attachments: pickedImages,
          onRemove: (File attachment) {
            pickedImages
                .removeWhere((element) => element.path == attachment.path);
            if (this.mounted) setState(() {});
          },
        ),
      );

  Widget buildTextFieldAlwaysVisible() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        buildShareButton(),
        buildActualTextField(),
      ],
    );
  }

  Widget buildShareButton() => Container(
        height: 35,
        width: 35,
        margin: EdgeInsets.only(left: 5.0, right: 5.0),
        child: ClipOval(
          child: Material(
            color: Theme.of(context).primaryColor,
            child: InkWell(
              onTap: toggleShareMenu,
              child: Padding(
                padding: EdgeInsets.only(right: 1),
                child: Icon(
                  Icons.share,
                  color: Colors.white.withAlpha(225),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );

  Widget buildActualTextField() {
    IconData rightIcon = Icons.arrow_upward;

    bool canRecord = controller.text.isEmpty && pickedImages.isEmpty;

    if (canRecord) rightIcon = Icons.mic;
    return Flexible(
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
              child: ThemeSwitcher(
                iOSSkin: CustomCupertinoTextField(
                  cursorColor: Theme.of(context).primaryColor,
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
                  onContentCommited: onContentCommit,
                  textCapitalization: TextCapitalization.sentences,
                  focusNode: focusNode,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyText1.apply(
                        color: ThemeData.estimateBrightnessForColor(
                                    Theme.of(context).backgroundColor) ==
                                Brightness.light
                            ? Colors.black
                            : Colors.white,
                        fontSizeDelta: -0.25,
                      ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                  placeholder: "BlueBubbles",
                  padding:
                      EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.subtitle1,
                  autofocus: SettingsManager().settings.autoOpenKeyboard,
                  decoration: BoxDecoration(
                    color: Theme.of(context).backgroundColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                materialSkin: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: true,
                  autofocus: SettingsManager().settings.autoOpenKeyboard,
                  cursorColor: Theme.of(context).primaryColor,
                  key: _searchFormKey,
                  style: Theme.of(context).textTheme.bodyText1.apply(
                        color: ThemeData.estimateBrightnessForColor(
                                    Theme.of(context).backgroundColor) ==
                                Brightness.light
                            ? Colors.black
                            : Colors.white,
                        fontSizeDelta: -0.25,
                      ),
                  onContentCommited: onContentCommit,
                  decoration: InputDecoration(
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    hintText: "BlueBubbles",
                    contentPadding: EdgeInsets.only(
                        left: 10, top: 15, right: 40, bottom: 10),
                    hintStyle: Theme.of(context).textTheme.subtitle1,
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                ),
              ),
            ),
            buildSendButton(canRecord),
          ],
        ),
      ),
    );
  }

  Future<void> startRecording() async {
    HapticFeedback.lightImpact();
    String appDocPath = SettingsManager().appDocDir.path;
    Directory directory = Directory("$appDocPath/attachments/");
    if (!await directory.exists()) {
      directory.createSync();
    }
    String pathName = "$appDocPath/attachments/AudioMessage.m4a";
    File file = new File(pathName);
    if (file.existsSync()) file.deleteSync();

    if (!isRecording) {
      await Record.start(
        path: pathName, // required
        encoder: AudioEncoder.AAC, // by default
        bitRate: 196000, // by default
        samplingRate: 44100, // by default
      );

      if (this.mounted) {
        setState(() {
          isRecording = true;
        });
      }
    }
  }

  Future<void> stopRecording() async {
    HapticFeedback.lightImpact();

    if (isRecording) {
      await Record.stop();

      if (this.mounted) {
        setState(() {
          isRecording = false;
        });
      }

      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/AudioMessage.m4a";
      reviewAudio(context, new File(pathName));
    }
  }

  Widget buildSendButton(bool canRecord) => Align(
        alignment: Alignment.bottomRight,
        child: ButtonTheme(
          minWidth: 30,
          height: 30,
          child: RaisedButton(
            padding: EdgeInsets.symmetric(
              horizontal: 0,
            ),
            color: Theme.of(context).primaryColor,
            onPressed: () async {
              if (isRecording) {
                await stopRecording();
              } else if (canRecord &&
                  !isRecording &&
                  await Permission.microphone.request().isGranted) {
                await startRecording();
              } else {
                if (await widget.onSend(pickedImages, controller.text)) {
                  controller.text = "";
                  pickedImages = <File>[];
                  updateTextFieldAttachments();
                }
              }
              if (this.mounted) setState(() {});
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: controller.text.isEmpty && pickedImages.isEmpty
                      ? 1.0
                      : 0.0,
                  duration: Duration(milliseconds: 150),
                  child: Icon(
                    Icons.mic,
                    color: (isRecording) ? Colors.red : Colors.white,
                    size: 20,
                  ),
                ),
                AnimatedOpacity(
                  opacity:
                      (controller.text.isNotEmpty || pickedImages.length > 0) &&
                              !isRecording
                          ? 1.0
                          : 0.0,
                  duration: Duration(milliseconds: 150),
                  child: Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
        ),
      );

  Widget buildAttachmentPicker() => TextFieldAttachmentPicker(
        visible: showImagePicker,
        onAddAttachment: (File file) {
          for (File image in pickedImages) {
            if (image.path == file.path) {
              pickedImages.removeWhere((element) => element.path == file.path);
              updateTextFieldAttachments();
              if (this.mounted) setState(() {});
              return;
            }
          }
          pickedImages.add(file);
          updateTextFieldAttachments();
          if (this.mounted) setState(() {});
        },
      );
}
