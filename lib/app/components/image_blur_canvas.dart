import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A widget that renders an image with a blurred fill background.
///
/// The background is a heavily-blurred, [BoxFit.cover] copy of the image that
/// fills all available space. The foreground is the same image centered with
/// [BoxFit.contain], so portrait or landscape images are never clipped or
/// anchored off-center.
///
/// This widget fills its parent — wrap in a [SizedBox] or [ConstrainedBox] to
/// control the canvas dimensions.
///
/// Either [filePath] or [bytes] must be provided.
///
/// Used by:
/// - [ImageDisplay] in the media gallery (square card background + foreground)
/// - [ImageViewer] when rendering image previews inside a reply bubble
class ImageBlurCanvas extends StatelessWidget {
  const ImageBlurCanvas({
    super.key,
    this.filePath,
    this.bytes,
  }) : assert(filePath != null || bytes != null, 'Either filePath or bytes must be provided');

  final String? filePath;
  final Uint8List? bytes;

  Widget _buildImg({required bool background, required int cacheWidth}) {
    if (filePath != null) {
      return Image.file(
        File(filePath!),
        fit: background ? BoxFit.cover : BoxFit.contain,
        alignment: Alignment.center,
        cacheWidth: background ? 64 : cacheWidth,
      );
    }
    return Image.memory(
      bytes!,
      fit: background ? BoxFit.cover : BoxFit.contain,
      alignment: Alignment.center,
      cacheWidth: background ? 64 : cacheWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rawWidth = (constraints.maxWidth * MediaQuery.of(context).devicePixelRatio).round().abs();
        final cacheWidth = rawWidth > 0 ? rawWidth : 1;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background: low-res image stretched to cover, blurred on the GPU.
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.decal),
              child: _buildImg(background: true, cacheWidth: cacheWidth),
            ),
            // Foreground: full-res image centered with BoxFit.contain.
            Center(child: _buildImg(background: false, cacheWidth: cacheWidth)),
          ],
        );
      },
    );
  }
}
