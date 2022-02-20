import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class AvatarCrop extends StatefulWidget {
  final int? index;
  final Chat? chat;
  AvatarCrop({this.index, this.chat});

  @override
  _AvatarCropState createState() => _AvatarCropState();
}

class _AvatarCropState extends State<AvatarCrop> {

  final _cropController = CropController();
  Uint8List? _imageData;
  bool _isLoading = true;

  void onCropped(Uint8List croppedData) async {
    String appDocPath = SettingsManager().appDocDir.path;
    if (widget.index != null) {
      File file = File(ChatBloc().chats[widget.index!].customAvatarPath ?? "$appDocPath/avatars/${ChatBloc().chats[widget.index!].guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
      if (ChatBloc().chats[widget.index!].customAvatarPath == null) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(croppedData);
      ChatBloc().chats[widget.index!].customAvatarPath = file.path;
      ChatBloc().chats[widget.index!].save(updateCustomAvatarPath: true);
      CustomNavigator.backSettings(context, closeOverlays: true);
      showSnackbar("Notice", "Custom chat avatar saved successfully");
    } else {
      File file = File(widget.chat!.customAvatarPath ?? "$appDocPath/avatars/${widget.chat!.guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
      if (widget.chat!.customAvatarPath == null) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(croppedData);
      widget.chat!.customAvatarPath = file.path;
      widget.chat!.save(updateCustomAvatarPath: true);
      Get.back(closeOverlays: true);
      showSnackbar("Notice", "Custom chat avatar saved successfully");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
          backgroundColor: Theme.of(context).backgroundColor,
          appBar: PreferredSize(
            preferredSize: Size(CustomNavigator.width(context), 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  systemOverlayStyle: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.dark
                      ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                  toolbarHeight: 100.0,
                  elevation: 0,
                  leading: buildBackButton(context),
                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                  title: Text(
                    "Select & Crop Image",
                    style: Theme.of(context).textTheme.headline1,
                  ),
                  actions: [
                    AbsorbPointer(
                      absorbing: _imageData == null || _isLoading,
                      child: TextButton(
                          child: Text("SAVE",
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle1!
                                  .apply(color: _imageData == null || _isLoading ? Colors.grey : Theme.of(context).primaryColor)),
                          onPressed: () {
                            Get.defaultDialog(
                              title: "Saving avatar...",
                              titleStyle: Theme.of(context).textTheme.headline1,
                              confirm: Container(height: 0, width: 0),
                              cancel: Container(height: 0, width: 0),
                              content: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    SizedBox(
                                      height: 15.0,
                                    ),
                                    buildProgressIndicator(context),
                                  ]
                              ),
                              barrierDismissible: false,
                              backgroundColor: Theme.of(context).backgroundColor,
                            );
                            _cropController.crop();
                          }),
                    ),
                  ],
                ),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              ),
            ),
          ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Column(
              children: [
                if (_imageData != null)
                  Container(
                    height: context.height / 2,
                    child: Crop(
                        controller: _cropController,
                        image: _imageData!,
                        onCropped: onCropped,
                        onStatusChanged: (status) {
                          if (status == CropStatus.ready || status == CropStatus.cropping) {
                            setState(() {
                              _isLoading = false;
                            });
                          } else {
                            setState(() {
                              _isLoading = true;
                            });
                          }
                        },
                        withCircleUi: true,
                        initialSize: 0.5,
                      ),
                  ),
                if (_imageData == null)
                  Container(
                    height: context.height / 2,
                    child: Center(
                      child: Text("Pick an image to crop it for a custom avatar"),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Theme.of(context).primaryColor)
                    ),
                    primary: Theme.of(context).backgroundColor,
                  ),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                    if (res.files.first.name.endsWith("gif")) {
                      Get.defaultDialog(
                        title: "Saving avatar...",
                        titleStyle: Theme.of(context).textTheme.headline1,
                        confirm: Container(height: 0, width: 0),
                        cancel: Container(height: 0, width: 0),
                        content: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                height: 15.0,
                              ),
                              buildProgressIndicator(context),
                            ]
                        ),
                        barrierDismissible: false,
                        backgroundColor: Theme.of(context).backgroundColor,
                      );
                      onCropped(res.files.first.bytes!);
                    } else {
                      _imageData = res.files.first.bytes!;
                      setState(() {});
                    }
                  },
                  child: Text(
                    _imageData != null ? "Pick New Image" : "Pick Image",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyText1!.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      ),
    );
  }
}