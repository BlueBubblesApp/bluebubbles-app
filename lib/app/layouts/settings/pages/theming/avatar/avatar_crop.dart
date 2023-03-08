import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
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

class _AvatarCropState extends OptimizedState<AvatarCrop> {
  final _cropController = CropController();
  Uint8List? _imageData;
  bool _isLoading = true;

  void onCropped(Uint8List croppedData) async {
    String appDocPath = fs.appDocDir.path;
    if (widget.index != null) {
      File file = File(chats.chats[widget.index!].customAvatarPath ?? "$appDocPath/avatars/${chats.chats[widget.index!].guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
      if (chats.chats[widget.index!].customAvatarPath == null) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(croppedData);
      chats.chats[widget.index!].refreshCustomAvatar(file.path);
      chats.chats[widget.index!].save(updateCustomAvatarPath: true);
      Navigator.of(context).pop();
      ns.backSettings(context);
      showSnackbar("Notice", "Custom chat avatar saved successfully");
    } else {
      File file = File(widget.chat!.customAvatarPath ?? "$appDocPath/avatars/${widget.chat!.guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
      if (widget.chat!.customAvatarPath == null) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(croppedData);
      widget.chat!.refreshCustomAvatar(file.path);
      widget.chat!.save(updateCustomAvatarPath: true);
      Navigator.of(context).pop();
      ns.backSettings(context, result: croppedData);
      showSnackbar("Notice", "Custom chat avatar saved successfully");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
          backgroundColor: context.theme.colorScheme.background,
          appBar: PreferredSize(
            preferredSize: Size(ns.width(context), 50),
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
              centerTitle: iOS,
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
                        showSavingAvatarDialog();
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
                    backgroundColor: context.theme.colorScheme.primaryContainer,
                  ),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                    if (res.files.first.name.endsWith("gif")) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Saving avatar...", style: context.theme.textTheme.titleLarge),
                          content: Container(
                            height: 70,
                            child: Center(
                              child: buildProgressIndicator(context),
                            ),
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

  void showSavingAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Saving avatar...", style: context.theme.textTheme.titleLarge),
        content: Container(
          height: 70,
          child: Center(
            child: buildProgressIndicator(context),
          ),
        ),
        backgroundColor: context.theme.colorScheme.properSurface,
      ),
      barrierDismissible: false,
    );
  }
}