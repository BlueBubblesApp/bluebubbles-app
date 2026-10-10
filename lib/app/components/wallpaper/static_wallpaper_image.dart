import 'package:flutter/widgets.dart';
import 'package:universal_io/io.dart';

/// Image provider for a chat's static background, decoded no larger than the
/// window needs.
///
/// Backgrounds are saved at up to 2560 px on their longest side (see
/// `background_crop.dart`). Decoding that at full size costs 12 MB or more per
/// chat, and the same again as a GPU texture while the chat is open. The wrapper
/// draws with `BoxFit.cover`, so the decode only has to match the window along
/// its longer axis; the other axis follows the image's own aspect ratio and ends
/// up at least window-sized for any photo-shaped image.
///
/// Every consumer (the wrapper and the precache on conversation open) must build
/// the provider through here. The image cache keys on the exact resize
/// parameters, and a mismatch means a second full decode. For the same reason
/// the wrapper does not follow the live window size during a desktop drag-resize:
/// it keeps the last settled size until the window stops moving (see
/// `GradientBackground._geometryToDecodeFor`), or every frame would be a decode.
ImageProvider chatBackgroundImageProvider(String path, BuildContext context) {
  return chatBackgroundImageProviderForWindow(
    path,
    MediaQuery.sizeOf(context),
    MediaQuery.devicePixelRatioOf(context),
  );
}

/// [chatBackgroundImageProvider] for callers that already know the window size.
ImageProvider chatBackgroundImageProviderForWindow(String path, Size logicalSize, double devicePixelRatio) {
  final FileImage file = FileImage(File(path));
  final int widthPx = (logicalSize.width * devicePixelRatio).round();
  final int heightPx = (logicalSize.height * devicePixelRatio).round();
  if (widthPx <= 0 || heightPx <= 0) return file;
  // One dimension only: ResizeImage scales the other to keep the aspect ratio,
  // and never upscales, so a file smaller than the window decodes as-is.
  return heightPx >= widthPx ? ResizeImage(file, height: heightPx) : ResizeImage(file, width: widthPx);
}
