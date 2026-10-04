import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

class AvatarCrop extends StatefulWidget {
  final int? index;
  final Chat? chat;

  const AvatarCrop({
    super.key,
    this.index,
    this.chat,
  });

  @override
  State<AvatarCrop> createState() => _AvatarCropState();
}

class _AvatarCropState extends State<AvatarCrop> with ThemeHelpers {
  final _cropController = CropController();
  Uint8List? _imageData;
  bool _isLoading = true;

  Future<void> _pickImageFromGallery() async {
    if (kIsDesktop || kIsWeb) return _pickImageFromFiles();

    final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    await _handlePickedImage(bytes, fileName: file.name);
  }

  Future<void> _pickImageFromFiles() async {
    final res = await FilePicker.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

    await _handlePickedImage(res.files.first.bytes!, fileName: res.files.first.name);
  }

  Future<void> _handlePickedImage(Uint8List bytes, {String? fileName}) async {
    final lowerName = (fileName ?? '').toLowerCase();
    if (lowerName.endsWith('.gif')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Saving avatar...", style: context.theme.textTheme.titleLarge),
          content: SizedBox(
            height: 70,
            child: Center(
              child: buildProgressIndicator(context),
            ),
          ),
          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
        ),
        barrierDismissible: false,
      );
      onCropped(CropSuccess(bytes));
      return;
    }

    _imageData = bytes;
    if (mounted) setState(() {});
  }

  void onCropped(CropResult croppedResult) async {
    Uint8List croppedData;
    switch (croppedResult) {
      case CropSuccess(:final croppedImage):
        croppedData = croppedImage;
        break;
      case CropFailure(:final cause, :final stackTrace):
        Navigator.of(context, rootNavigator: true).pop();
        showSnackbar("Error", "Failed to crop image", type: SnackbarType.error);
        Logger.debug("Failed to crop image");
        Logger.error(cause);
        Logger.error(stackTrace);
        return;
    }

    if (widget.index == null && widget.chat == null) {
      File file = File(p.join(FilesystemSvc.avatarsPath, "you", "avatar-${croppedData.length}.jpg"));
      if (!(await file.exists())) {
        await file.create(recursive: true);
      }
      if (SettingsSvc.settings.userAvatarPath.value != null) {
        await File(SettingsSvc.settings.userAvatarPath.value!).delete();
      }
      await file.writeAsBytes(croppedData);
      SettingsSvc.settings.userAvatarPath.value = file.path;
      await SettingsSvc.settings.saveOneAsync("userAvatarPath");
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop();
    } else if (widget.chat != null) {
      File file = File(p.join(FilesystemSvc.avatarsPath, FilesystemService.sanitizeGuid(widget.chat!.guid),
          "avatar-${croppedData.length}.jpg"));
      if (!(await file.exists())) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(croppedData);

      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop(file.path);
    } else {
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      appBar: BBAppBar(
        titleText: "Select & Crop Avatar",
        leading: buildBackButton(context),
        actions: [
          AbsorbPointer(
            absorbing: _imageData == null || _isLoading,
            child: TextButton(
                child: Text("SAVE",
                    style: context.theme.textTheme.bodyLarge!.apply(
                        color: _imageData == null || _isLoading
                            ? context.theme.colorScheme.outline
                            : context.theme.colorScheme.primary)),
                onPressed: () {
                  showSavingAvatarDialog();
                  _cropController.crop();
                }),
          ),
        ],
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            children: [
              if (_imageData != null)
                SizedBox(
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
                  ),
                ),
              if (_imageData == null)
                SizedBox(
                  height: context.height / 2,
                  child: Center(
                    child:
                        Text("Pick an image to crop it for a custom avatar", style: context.theme.textTheme.bodyLarge),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: context.theme.colorScheme.onPrimaryContainer)),
                  backgroundColor: context.theme.colorScheme.primaryContainer,
                ),
                onPressed: _pickImageFromGallery,
                child: Text(_imageData != null ? "Pick New Image" : "Pick Image",
                    style: context.theme.textTheme.bodyLarge!
                        .copyWith(color: context.theme.colorScheme.onPrimaryContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showSavingAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Saving avatar...", style: context.theme.textTheme.titleLarge),
        content: SizedBox(
          height: 70,
          child: Center(
            child: buildProgressIndicator(context),
          ),
        ),
        backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      ),
      barrierDismissible: false,
    );
  }
}
