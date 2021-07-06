import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/text_field_attachment_list.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:camera/camera.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime_type/mime_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';

class BlueBubblesTextField extends StatefulWidget {
  final List<File>? existingAttachments;
  final String? existingText;
  final bool? isCreator;
  final bool wasCreator;
  final Future<bool> Function(List<File> attachments, String text) onSend;

  BlueBubblesTextField({
    Key? key,
    this.existingAttachments,
    this.existingText,
    required this.isCreator,
    required this.wasCreator,
    required this.onSend,
  }) : super(key: key);

  static BlueBubblesTextFieldState? of(BuildContext context) {
    return context.findAncestorStateOfType<BlueBubblesTextFieldState>();
  }

  @override
  BlueBubblesTextFieldState createState() => BlueBubblesTextFieldState();
}

class BlueBubblesTextFieldState extends State<BlueBubblesTextField> with TickerProviderStateMixin {
  TextEditingController? controller;
  FocusNode? focusNode;
  bool showImagePicker = false;
  List<File> pickedImages = <File>[];
  bool isRecording = false;
  TextFieldData? textFieldData;
  StreamController _streamController = new StreamController.broadcast();
  CurrentChat? safeChat;

  bool selfTyping = false;
  CameraController? cameraController;
  int cameraIndex = 0;
  late List<CameraDescription> cameras;
  int? sendCountdown;
  bool? stopSending;
  String? placeholder = "BlueBubbles";

  // bool selfTyping = false;

  Stream get stream => _streamController.stream;

  bool get canRecord => controller!.text.isEmpty && pickedImages.isEmpty;

  final GlobalKey<FormFieldState<String>> _searchFormKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    getPlaceholder();

    if (CurrentChat.of(context)?.chat != null) {
      textFieldData = TextFieldBloc().getTextField(CurrentChat.of(context)!.chat.guid);
    }

    controller = textFieldData != null ? textFieldData!.controller : new TextEditingController();

    // Add the text listener to detect when we should send the typing indicators
    controller!.addListener(() {
      if (mounted && CurrentChat.of(context)?.chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!SettingsManager().settings.enablePrivateAPI || !SettingsManager().settings.sendTypingIndicators) {
        if (this.mounted) setState(() {});
        return;
      }

      if (controller!.text.length == 0 && pickedImages.length == 0 && selfTyping) {
        selfTyping = false;
        SocketManager().sendMessage("stopped-typing", {"chatGuid": CurrentChat.of(context)!.chat.guid}, (data) {});
      } else if (!selfTyping && (controller!.text.length > 0 || pickedImages.length > 0)) {
        selfTyping = true;
        if (SettingsManager().settings.sendTypingIndicators)
          SocketManager().sendMessage("started-typing", {"chatGuid": CurrentChat.of(context)!.chat.guid}, (data) {});
      }

      if (this.mounted) setState(() {});
    });

    // Create the focus node and then add a an event emitter whenever
    // the focus changes
    focusNode = new FocusNode();
    focusNode!.addListener(() {
      if (focusNode!.hasFocus && this.mounted) {
        showImagePicker = false;
        setState(() {});
      }

      EventDispatcher().emit("keyboard-status", focusNode!.hasFocus);
    });

    EventDispatcher().stream.listen((event) {
      if (!event.containsKey("type")) return;
      if (event["type"] == "unfocus-keyboard" && focusNode!.hasFocus) {
        focusNode!.unfocus();
      } else if (event["type"] == "focus-keyboard" && !focusNode!.hasFocus) {
        focusNode!.requestFocus();
      }
    });

    if (widget.existingText != null) {
      controller!.text = widget.existingText!;
    }

    if (widget.existingAttachments != null) {
      this.addAttachments(widget.existingAttachments!);
      updateTextFieldAttachments();
    }

    if (textFieldData != null) {
      this.addAttachments(textFieldData?.attachments ?? []);
    }
  }

  void addAttachments(List<File> attachments) {
    pickedImages.addAll(attachments);
    final ids = pickedImages.map((e) => e.path).toSet();
    pickedImages.retainWhere((element) => ids.remove(element.path));
  }

  void updateTextFieldAttachments() {
    if (textFieldData != null) {
      textFieldData!.attachments = pickedImages.where((element) => mime(element.path) != null).toList();
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
    focusNode!.dispose();
    _streamController.close();
    cameraController?.dispose();
    if (safeChat?.chat == null) controller!.dispose();

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

  void onContentCommit(Map<String, Object> content) async {
    // Add some debugging logs
    debugPrint("[Content Commit] Keyboard received content");
    debugPrint("  -> Content Type: ${content['mimeType']}");
    debugPrint("  -> URI: ${content['uri']}");
    debugPrint("  -> Content Length: ${content['data'] != null ? (content['data'] as List<dynamic>).length : "null"}");

    // Parse the filename from the URI and read the data as a List<int>
    String filename = uriToFilename(content['uri'] as String?, content['mimeType'] as String?);
    List<int> data = ((content['data'] ?? []) as List).map((e) => e as int).toList();

    // Save the data to a location and add it to the file picker
    File file = await _saveData(data, filename);
    this.addAttachments([file]);

    // Update the state
    updateTextFieldAttachments();
    if (this.mounted) setState(() {});
  }

  Future<void> reviewAudio(BuildContext originalContext, File file) async {
    showDialog(
      context: originalContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).accentColor,
          title: new Text("Send it?", style: Theme.of(context).textTheme.headline1),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Review your audio snippet before sending it", style: Theme.of(context).textTheme.subtitle1),
              Container(height: 10.0),
              AudioPlayerWiget(
                key: new Key("AudioMessage-${file.length().toString()}"),
                file: file,
                context: originalContext,
              )
            ],
          ),
          actions: <Widget>[
            new TextButton(
                child: new Text("Discard", style: Theme.of(context).textTheme.subtitle1),
                onPressed: () {
                  // Dispose of the audio controller
                  CurrentChat.of(originalContext)?.audioPlayers.removeWhere((key, _) => key == file.path);

                  // Delete the file
                  file.delete();

                  // Remove the OG alert dialog
                  Navigator.of(originalContext).pop();
                }),
            new TextButton(
              child: new Text(
                "Send",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              onPressed: () async {
                widget.onSend([file], "");

                // Dispose of the audio controller
                CurrentChat.of(originalContext)?.audioPlayers.removeWhere((key, _) => key == file.path);

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
    // If we are already initialized, don't do anything
    bool alreadyInit = cameraController?.value.isInitialized ?? false;
    if (alreadyInit) {
      await cameraController!.dispose();
    }

    // Enumerate the cameras
    cameras = await availableCameras();

    // Disable audio so that background music doesn't stop playing
    cameraController = CameraController(cameras[cameraIndex], ResolutionPreset.max, enableAudio: false);

    // Initialize the camera, then update the state
    if (!cameraController!.value.isInitialized) {
      await cameraController!.initialize();
    }
    if (this.mounted) setState(() {});
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

  Future<File> _saveData(List<int> data, String filename) async {
    String dir = SettingsManager().appDocDir.path;
    Directory tempAssets = Directory("$dir/tempAssets");
    if (!await tempAssets.exists()) {
      await tempAssets.create();
    }
    File file = new File('$dir/tempAssets/$filename');
    await file.writeAsBytes(data);
    return file;
  }

  Future<bool> _onWillPop() async {
    if (showImagePicker) {
      if (this.mounted) {
        setState(() {
          showImagePicker = false;
        });
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: _onWillPop,
        child: Row(
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
        ));
  }

  Widget buildAttachmentList() => Padding(
        padding: const EdgeInsets.only(left: 50.0),
        child: TextFieldAttachmentList(
          attachments: pickedImages,
          onRemove: (File attachment) {
            pickedImages.removeWhere((element) => element.path == attachment.path);
            updateTextFieldAttachments();
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
        if (SettingsManager().settings.skin == Skins.Material || SettingsManager().settings.skin == Skins.Samsung)
          buildSendButton(canRecord),
      ],
    );
  }

  Widget buildShareButton() {
    double size = SettingsManager().settings.skin == Skins.iOS ? 35 : 40;
    return Container(
      height: size,
      width: size,
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
  }

  Future<void> getPlaceholder() async {
    String? placeholder = "BlueBubbles";

    try {
      // Don't do anything if this setting isn't enabled
      if (SettingsManager().settings.recipientAsPlaceholder) {
        // Redacted mode stuff
        final bool hideInfo = SettingsManager().settings.redactedMode && SettingsManager().settings.hideContactInfo;
        final bool generateNames =
            SettingsManager().settings.redactedMode && SettingsManager().settings.generateFakeContactNames;

        // If it's a group chat, get the title of the chat
        if (CurrentChat.of(context)?.chat.isGroup() ?? false) {
          if (generateNames) {
            placeholder = "Group Chat";
          } else if (hideInfo) {
            placeholder = "BlueBubbles";
          } else {
            String? title = await CurrentChat.of(context)?.chat.getTitle();
            if (!isNullOrEmpty(title)!) {
              placeholder = title;
            }
          }
        } else if (!isNullOrEmpty(CurrentChat.of(context)?.chat.participants)!) {
          if (generateNames) {
            placeholder = CurrentChat.of(context)!.chat.fakeParticipants[0];
          } else if (hideInfo) {
            placeholder = "BlueBubbles";
          } else {
            // If it's not a group chat, get the participant's contact info
            String? address = CurrentChat.of(context)?.chat.participants[0].address;
            Contact? contact = ContactManager().getCachedContactSync(address);
            if (contact == null) {
              placeholder = await formatPhoneNumber(address!);
            } else {
              placeholder = contact.displayName ?? "BlueBubbles";
            }
          }
        }
      }
    } catch (ex) {
      debugPrint("Error setting Text Field Placeholder!");
      debugPrint(ex.toString());
    }

    if (placeholder != this.placeholder) {
      this.placeholder = placeholder;
      if (this.mounted) setState(() {});
    }
  }

  Widget buildActualTextField() {
    IconData rightIcon = Icons.arrow_upward;

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
                  enabled: sendCountdown == null,
                  textInputAction:
                      SettingsManager().settings.sendWithReturn ? TextInputAction.send : TextInputAction.newline,
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
                    } else if (value.isNotEmpty && rightIcon == Icons.mic && this.mounted) {
                      setState(() {
                        rightIcon = Icons.arrow_upward;
                      });
                    }
                  },
                  onSubmitted: (String value) async {
                    if (!SettingsManager().settings.sendWithReturn || isNullOrEmpty(value)!) return;

                    // If send delay is enabled, delay the sending
                    if (!isNullOrZero(SettingsManager().settings.sendDelay)) {
                      // Break the delay into 1 second intervals
                      for (var i = 0; i < SettingsManager().settings.sendDelay!; i++) {
                        if (i != 0 && sendCountdown == null) break;

                        // Update UI with new state information
                        if (this.mounted) {
                          setState(() {
                            sendCountdown = SettingsManager().settings.sendDelay! - i;
                          });
                        }

                        await Future.delayed(new Duration(seconds: 1));
                      }
                    }

                    if (this.mounted) {
                      setState(() {
                        sendCountdown = null;
                      });
                    }

                    if (stopSending != null && stopSending!) {
                      stopSending = null;
                      return;
                    }

                    if (await widget.onSend(pickedImages, value)) {
                      controller!.text = "";
                      pickedImages = <File>[];
                      updateTextFieldAttachments();
                    }

                    if (this.mounted) setState(() {});
                  },
                  onContentCommited: onContentCommit,
                  textCapitalization: TextCapitalization.sentences,
                  focusNode: focusNode,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                        color:
                            ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                                ? Colors.black
                                : Colors.white,
                        fontSizeDelta: -0.25,
                      ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                  placeholder: SettingsManager().settings.recipientAsPlaceholder == true ? placeholder : "BlueBubbles",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
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
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                        color:
                            ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
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
                    hintText: SettingsManager().settings.recipientAsPlaceholder == true ? placeholder : "BlueBubbles",
                    hintStyle: Theme.of(context).textTheme.subtitle1,
                    contentPadding: EdgeInsets.only(
                      left: 10,
                      top: 15,
                      right: 10,
                      bottom: 10,
                    ),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                ),
                samsungSkin: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: true,
                  autofocus: SettingsManager().settings.autoOpenKeyboard,
                  cursorColor: Theme.of(context).primaryColor,
                  key: _searchFormKey,
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                        color:
                            ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
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
                    hintText: SettingsManager().settings.recipientAsPlaceholder == true ? placeholder : "BlueBubbles",
                    hintStyle: Theme.of(context).textTheme.subtitle1,
                    contentPadding: EdgeInsets.only(
                      left: 10,
                      top: 15,
                      right: 10,
                      bottom: 10,
                    ),
                  ),
                ),
              ),
            ),
            if (SettingsManager().settings.skin == Skins.iOS) buildSendButton(canRecord),
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
    String pathName = "$appDocPath/attachments/OutgoingAudioMessage.m4a";
    File file = new File(pathName);
    if (file.existsSync()) file.deleteSync();

    if (!isRecording) {
      await Record().start(
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
      await Record().stop();

      if (this.mounted) {
        setState(() {
          isRecording = false;
        });
      }

      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/OutgoingAudioMessage.m4a";
      reviewAudio(context, new File(pathName));
    }
  }

  Future<void> sendAction() async {
    if (sendCountdown != null) {
      stopSending = true;
      sendCountdown = null;
      if (this.mounted) setState(() {});
    } else if (isRecording) {
      await stopRecording();
    } else if (canRecord && !isRecording && await Permission.microphone.request().isGranted) {
      await startRecording();
    } else {
      // If send delay is enabled, delay the sending
      if (!isNullOrZero(SettingsManager().settings.sendDelay)) {
        // Break the delay into 1 second intervals
        for (var i = 0; i < SettingsManager().settings.sendDelay!; i++) {
          if (i != 0 && sendCountdown == null) break;

          // Update UI with new state information
          if (this.mounted) {
            setState(() {
              sendCountdown = SettingsManager().settings.sendDelay! - i;
            });
          }

          await Future.delayed(new Duration(seconds: 1));
        }
      }

      if (this.mounted) {
        setState(() {
          sendCountdown = null;
        });
      }

      if (stopSending != null && stopSending!) {
        stopSending = null;
        return;
      }

      if (await widget.onSend(pickedImages, controller!.text)) {
        controller!.text = "";
        pickedImages = <File>[];
        updateTextFieldAttachments();
      }
    }

    if (this.mounted) setState(() {});
  }

  Widget buildSendButton(bool canRecord) => Align(
        alignment: Alignment.bottomRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (sendCountdown != null) Text(sendCountdown.toString()),
          (SettingsManager().settings.skin == Skins.iOS)
              ? ButtonTheme(
                  minWidth: 30,
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 0,
                      ),
                      primary: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    onPressed: sendAction,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: sendCountdown == null && controller!.text.isEmpty && pickedImages.isEmpty ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 150),
                          child: Icon(
                            Icons.mic,
                            color: (isRecording) ? Colors.red : Colors.white,
                            size: 20,
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: (sendCountdown == null && (controller!.text.isNotEmpty || pickedImages.length > 0)) &&
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
                        AnimatedOpacity(
                          opacity: sendCountdown != null ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 50),
                          child: Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  onTapDown: (_) async {
                    if (canRecord && !isRecording) {
                      await startRecording();
                    }
                  },
                  onTapCancel: () async {
                    await stopRecording();
                  },
                  child: ButtonTheme(
                    minWidth: 40,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 0,
                        ),
                        primary: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      onPressed: sendAction,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedOpacity(
                            opacity:
                                sendCountdown == null && controller!.text.isEmpty && pickedImages.isEmpty ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 150),
                            child: Icon(
                              Icons.mic,
                              color: (isRecording) ? Colors.red : Colors.white,
                              size: 20,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity:
                                (sendCountdown == null && (controller!.text.isNotEmpty || pickedImages.length > 0)) &&
                                        !isRecording
                                    ? 1.0
                                    : 0.0,
                            duration: Duration(milliseconds: 150),
                            child: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: sendCountdown != null ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 50),
                            child: Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ]),
      );

  Widget buildAttachmentPicker() => TextFieldAttachmentPicker(
        visible: showImagePicker,
        onAddAttachment: (File? file) {
          if (file == null) return;
          bool exists = file.existsSync();
          if (!exists) return;

          for (File image in pickedImages) {
            if (image.path == file.path) {
              pickedImages.removeWhere((element) => element.path == file.path);
              updateTextFieldAttachments();
              if (this.mounted) setState(() {});
              return;
            }
          }

          this.addAttachments([file]);
          updateTextFieldAttachments();
          if (this.mounted) setState(() {});
        },
      );
}
