import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';

class CropSample extends StatefulWidget {
  final Chat chat;
  CropSample({required this.chat});

  @override
  _CropSampleState createState() => _CropSampleState();
}

class _CropSampleState extends State<CropSample> {

  final _cropController = CropController();
  Uint8List? _imageData;

  var _loadingImage = false;

  var _isSumbnail = false;
  var _isCropping = false;
  var _isCircleUi = false;
  Uint8List? _croppedData;
  var _statusText = '';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
          backgroundColor: Theme.of(context).backgroundColor,
          appBar: PreferredSize(
            preferredSize: Size(context.width, 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                  toolbarHeight: 100.0,
                  elevation: 0,
                  leading: buildBackButton(context),
                  backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                  title: Text(
                    "Select & Crop Image",
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              ),
            ),
          ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Visibility(
              visible: !_loadingImage && !_isCropping,
              child: Column(
                children: [
                  if (_imageData != null)
                    Container(
                      height: context.height / 2,
                      child: Crop(
                          controller: _cropController,
                          image: _imageData!,
                          onCropped: (croppedData) {
                            setState(() {
                              _croppedData = croppedData;
                              _isCropping = false;
                            });
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
                      ),
                      primary: Theme.of(context).primaryColor,
                    ),
                    onPressed: () async {
                      List<dynamic>? res = await MethodChannelInterface().invokeMethod("pick-file", {
                        "mimeTypes": ["image/*"],
                        "allowMultiple": false,
                      });
                      if (res == null || res.isEmpty) return;

                      setState(() {
                        _imageData = File(res.first.toString()).readAsBytesSync();
                      });
                    },
                    child: Text(
                      "Pick Image",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyText1!.color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              replacement: const CircularProgressIndicator(),
            ),
          ),
        )
      ),
    );
  }
}