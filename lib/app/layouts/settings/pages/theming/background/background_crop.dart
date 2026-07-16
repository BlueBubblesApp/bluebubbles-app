import 'dart:ui' as ui;

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

enum _EditStep { selectImage, crop, blur }

class BackgroundCrop extends StatefulWidget {
  final Chat chat;

  const BackgroundCrop({super.key, required this.chat});

  @override
  State<BackgroundCrop> createState() => _BackgroundCropState();
}

class _BackgroundCropState extends State<BackgroundCrop> with ThemeHelpers {
  final _cropController = CropController();
  _EditStep _currentStep = _EditStep.selectImage;
  Uint8List? _imageData;
  Uint8List? _croppedData;
  bool _isLoading = false;
  bool _isLocked = true;
  double _blurSigma = 0.0;

  Chat get chat => widget.chat;

  Future<Uint8List> _applyBlurToImage(Uint8List bytes, double sigma) async {
    if (sigma == 0) return bytes;

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    canvas.drawImage(sourceImage, Offset.zero, paint);
    final picture = recorder.endRecording();
    final blurredImage = await picture.toImage(sourceImage.width, sourceImage.height);
    final byteData = await blurredImage.toByteData(format: ui.ImageByteFormat.png);

    sourceImage.dispose();
    blurredImage.dispose();

    return byteData!.buffer.asUint8List();
  }

  void onCropped(CropResult croppedResult) {
    switch (croppedResult) {
      case CropSuccess(:final croppedImage):
        if (mounted) {
          setState(() {
            _croppedData = croppedImage;
            _currentStep = _EditStep.blur;
          });
        }
      case CropFailure(:final cause, :final stackTrace):
        showSnackbar("Error", "Failed to crop image");
        Logger.error(cause);
        Logger.error(stackTrace);
    }
  }

  Future<void> _saveImage() async {
    _showSavingDialog();
    final Uint8List finalData = await _applyBlurToImage(_croppedData!, _blurSigma);
    final String sanitizedGuid = FilesystemService.sanitizeGuid(chat.guid);
    final File file =
        File(p.join(FilesystemSvc.customBackgroundsPath, sanitizedGuid, "background-${finalData.length}.png"));

    if (!(await file.exists())) {
      await file.create(recursive: true);
    }

    // Delete the old background file if one exists
    if (chat.customBackgroundPath != null) {
      final File oldFile = File(chat.customBackgroundPath!);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    await file.writeAsBytes(finalData);
    await ChatsSvc.setChatCustomBackgroundPath(chat, file.path);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pop(file.path);
    showSnackbar("Notice", "Custom background saved successfully");
  }

  @override
  Widget build(BuildContext context) {
    final double screenAspectRatio = NavigationSvc.width(context) / context.height;
    return BBScaffold(
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(context, screenAspectRatio),
      body: _buildBody(context, screenAspectRatio),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, double screenAspectRatio) {
    switch (_currentStep) {
      case _EditStep.selectImage:
        return BBAppBar(
          titleText: "Set Custom Background",
          leading: buildBackButton(context),
        );
      case _EditStep.crop:
        return BBAppBar(
          titleText: "Crop Image",
          leading: buildBackButton(context, callback: () {
            setState(() {
              _currentStep = _EditStep.selectImage;
              _isLoading = false;
            });
            return false;
          }),
          actions: [
            IconButton(
              tooltip: _isLocked ? "Switch to free-form crop" : "Lock to screen ratio",
              icon: Icon(
                _isLocked
                    ? (iOS ? CupertinoIcons.lock : Icons.lock_outline)
                    : (iOS ? CupertinoIcons.lock_open : Icons.lock_open_outlined),
              ),
              onPressed: () {
                setState(() {
                  _isLocked = !_isLocked;
                });
                _cropController.aspectRatio = _isLocked ? screenAspectRatio : null;
              },
            ),
            AbsorbPointer(
              absorbing: _isLoading,
              child: TextButton(
                child: Text(
                  "NEXT",
                  style: context.theme.textTheme.bodyLarge!.apply(
                    color: _isLoading ? context.theme.colorScheme.outline : context.theme.colorScheme.primary,
                  ),
                ),
                onPressed: () => _cropController.crop(),
              ),
            ),
          ],
        );
      case _EditStep.blur:
        return BBAppBar(
          titleText: "Adjust Blur",
          leading: buildBackButton(context, callback: () {
            setState(() {
              _currentStep = _EditStep.crop;
              _croppedData = null;
              _isLoading = true;
            });
            return false;
          }),
          actions: [
            TextButton(
              onPressed: _saveImage,
              child: Text(
                "SAVE",
                style: context.theme.textTheme.bodyLarge!.apply(
                  color: context.theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildBody(BuildContext context, double screenAspectRatio) {
    switch (_currentStep) {
      case _EditStep.selectImage:
        return _buildSelectImageStep(context);
      case _EditStep.crop:
        return _buildCropStep(context, screenAspectRatio);
      case _EditStep.blur:
        return _buildBlurStep(context);
    }
  }

  Widget _buildSelectImageStep(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _imageData != null
              ? Image.memory(_imageData!, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
              : Center(
                  child: Text(
                    "Pick an image to use as the chat background",
                    style: context.theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: context.theme.colorScheme.onPrimaryContainer),
            ),
            backgroundColor: context.theme.colorScheme.primaryContainer,
          ),
          onPressed: () async {
            final res = await FilePicker.pickFiles(
              withData: true,
              type: FileType.custom,
              allowedExtensions: ['png', 'jpg', 'jpeg'],
            );
            if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
            setState(() {
              _imageData = res.files.first.bytes!;
              _croppedData = null;
              _currentStep = _EditStep.crop;
              _isLoading = true;
            });
          },
          child: Text(
            _imageData != null ? "Pick New Image" : "Pick Image",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onPrimaryContainer),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }

  Widget _buildCropStep(BuildContext context, double screenAspectRatio) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Crop(
                  controller: _cropController,
                  image: _imageData!,
                  onCropped: onCropped,
                  onStatusChanged: (status) {
                    setState(() {
                      _isLoading = status != CropStatus.ready;
                    });
                  },
                  withCircleUi: false,
                  aspectRatio: _isLocked ? screenAspectRatio : null,
                  baseColor: context.theme.colorScheme.surface,
                  maskColor: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: context.theme.colorScheme.surface.withValues(alpha: 0.6),
                    child: Center(child: buildProgressIndicator(context)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlurStep(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _blurSigma,
              sigmaY: _blurSigma,
              tileMode: TileMode.decal,
            ),
            child: Image.memory(
              _croppedData!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        ..._buildBlurSlider(context),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }

  List<Widget> _buildBlurSlider(BuildContext context) {
    return [
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              iOS ? CupertinoIcons.wand_stars : Icons.blur_on_outlined,
              size: 18,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: 10,
                value: _blurSigma,
                onChanged: (value) {
                  setState(() {
                    _blurSigma = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                _blurSigma == 0 ? "No blur" : _blurSigma.toStringAsFixed(1),
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _showSavingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Processing image...", style: context.theme.textTheme.titleLarge),
        content: SizedBox(
          height: 70,
          child: Center(child: buildProgressIndicator(context)),
        ),
        backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      ),
      barrierDismissible: false,
    );
  }
}
