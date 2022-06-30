import 'dart:typed_data';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
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
  State<AvatarCrop> createState() => _AvatarCropState();
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
      Navigator.of(context).pop();
      CustomNavigator.backSettings(context);
      showSnackbar("Notice", "Custom chat avatar saved successfully");
    } else {
      File file = File(widget.chat!.customAvatarPath ?? "$appDocPath/avatars/${widget.chat!.guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
      if (widget.chat!.customAvatarPath == null) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(croppedData);
      widget.chat!.customAvatarPath = file.path;
      widget.chat!.save(updateCustomAvatarPath: true);
      Navigator.of(context).pop();
      CustomNavigator.backSettings(context);
      showSnackbar("Notice", "Custom chat avatar saved successfully");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
          backgroundColor: context.theme.colorScheme.background,
          appBar: PreferredSize(
            preferredSize: Size(CustomNavigator.width(context), 50),
            child: AppBar(
              systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              toolbarHeight: 50,
              elevation: 0,
              scrolledUnderElevation: 3,
              surfaceTintColor: context.theme.colorScheme.primary,
              leading: buildBackButton(context),
              backgroundColor: headerColor,
              centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
              title: Text(
                "Select & Crop Avatar",
                style: context.theme.textTheme.titleLarge,
              ),
              actions: [
                AbsorbPointer(
                  absorbing: _imageData == null || _isLoading,
                  child: TextButton(
                      child: Text("SAVE",
                          style: context.theme.textTheme.bodyLarge!
                              .apply(color: _imageData == null || _isLoading ? context.theme.colorScheme.outline : context.theme.colorScheme.primary)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Saving avatar...", style: context.theme.textTheme.titleLarge),
                            content: Padding(
                              padding: const EdgeInsets.only(top: 15.0),
                              child: buildProgressIndicator(context),
                            ),
                            backgroundColor: context.theme.colorScheme.properSurface,
                          ),
                          barrierDismissible: false,
                        );
                        _cropController.crop();
                      }),
                ),
              ],
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
                      child: Text("Pick an image to crop it for a custom avatar", style: context.theme.textTheme.bodyLarge),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.theme.colorScheme.onPrimaryContainer)
                    ),
                    primary: context.theme.colorScheme.primaryContainer,
                  ),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                    if (res.files.first.name.endsWith("gif")) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Saving avatar...", style: context.theme.textTheme.titleLarge),
                          content: Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: buildProgressIndicator(context),
                          ),
                          backgroundColor: context.theme.colorScheme.properSurface,
                        ),
                        barrierDismissible: false,
                      );
                      onCropped(res.files.first.bytes!);
                    } else {
                      _imageData = res.files.first.bytes!;
                      setState(() {});
                    }
                  },
                  child: Text(
                    _imageData != null ? "Pick New Image" : "Pick Image",
                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onPrimaryContainer)
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