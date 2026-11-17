import 'dart:async';
import 'dart:ui' as ui;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/tapback_icon.dart';
import 'package:bluebubbles/helpers/ui/reaction_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

/// PNGs for Windows toast buttons, so tapbacks show the app's gradient glyphs and emoji draw in the app's emoji font
/// rather than whatever the system font has.
class ToastButtonImages {
  // Windows draws button icons at 16px; this leaves room for 4x display scaling
  static const int _size = 64;

  /// Bump when the drawing changes, so images cached by an older version are drawn again
  static const int _version = 2;

  static bool _prunedOldVersions = false;

  static Future<void> _pruneOldVersions(Directory root) async {
    try {
      if (!await root.exists()) return;
      await for (final entry in root.list()) {
        if (basename(entry.path) != '$_version') await entry.delete(recursive: true);
      }
    } on FileSystemException catch (e) {
      Logger.warn('Failed to remove old toast button images: $e', tag: 'ToastButtonImages');
    }
  }

  /// A button image for a tapback action: a classic tapback, or an emoji
  static Future<String?> forAction(String action) async {
    final emojiFont = FilesystemSvc.fontExistsOnDisk.value;
    final named = ReactionTypes.toList().contains(action);
    // Named by code point: an emoji can't go in a file name
    final key = named
        ? action
        : 'emoji-${action.runes.map((r) => r.toRadixString(16)).join('-')}${emojiFont ? '-apple' : ''}';
    final root = Directory(join(FilesystemSvc.appDocDir.path, 'toast_buttons'));
    if (!_prunedOldVersions) {
      _prunedOldVersions = true;
      unawaited(_pruneOldVersions(root));
    }
    final file = File(join(root.path, '$_version', '$key.png'));
    if (await file.exists()) return file.path;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final bounds = Offset.zero & const Size.square(_size + 0.0);
      // Named tapbacks are their icons, as on messages, so they don't look like the same emoji
      if (named) {
        await _paintTapback(canvas, bounds, action);
      } else {
        _paintText(canvas, action, emojiFont);
      }
      final image = await _lightened(await _trimmed(await recorder.endRecording().toImage(_size, _size)));
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) return null;
      await file.create(recursive: true);
      await file.writeAsBytes(png.buffer.asUint8List());
      return file.path;
    } catch (e, s) {
      Logger.warn('Failed to draw toast button image for $action', error: e, trace: s, tag: 'ToastButtonImages');
      return null;
    }
  }

  /// Windows themes button images it takes for glyphs, inverting them against the notification's background, and
  /// darker images get taken for glyphs. Tested on real notifications: emphasize (luminance 121) was inverted on
  /// light and accent backgrounds, and was left alone from 145 in light, dark and accent alike, as love, laugh and
  /// like (139+) are. So a darker image is blended toward white until it reaches 145, which keeps its hue. Images of
  /// one flat color are themed regardless, so emoji drawn that way can still be inverted.
  static const double _minLuminance = 145;

  static Future<ui.Image> _lightened(ui.Image image) async {
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (pixels == null) return image;
    double sum = 0, weight = 0;
    for (int i = 0; i < pixels.lengthInBytes; i += 4) {
      final alpha = pixels.getUint8(i + 3) / 255;
      if (alpha == 0) continue;
      sum += alpha *
          (0.2126 * pixels.getUint8(i) + 0.7152 * pixels.getUint8(i + 1) + 0.0722 * pixels.getUint8(i + 2));
      weight += alpha;
    }
    final luminance = weight == 0 ? 255.0 : sum / weight;
    if (luminance >= _minLuminance) return image;
    final recorder = ui.PictureRecorder();
    final bounds = Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
    Canvas(recorder)
      ..drawImage(image, Offset.zero, Paint())
      // srcATop: only over what's drawn, so the shape and its edges stay as they were
      ..drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = Colors.white.withValues(alpha: (_minLuminance - luminance) / (255 - luminance)),
      );
    final lightened = await recorder.endRecording().toImage(image.width, image.height);
    image.dispose();
    return lightened;
  }

  /// [image] cropped to what's drawn and scaled back up to fill it. Windows draws button images at a fixed size, so
  /// the glyph's own padding (an emoji's line height, an SVG's margin) would only make it look smaller.
  static Future<ui.Image> _trimmed(ui.Image image) async {
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) return image;
    int left = _size, top = _size, right = -1, bottom = -1;
    for (int y = 0; y < _size; y++) {
      for (int x = 0; x < _size; x++) {
        if (pixels.getUint8((y * _size + x) * 4 + 3) == 0) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < 0) return image;
    final ink = Rect.fromLTRB(left + 0.0, top + 0.0, right + 1.0, bottom + 1.0);
    final scale = _size / ink.longestSide;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      ink,
      Rect.fromCenter(
          center: const Offset(_size / 2, _size / 2), width: ink.width * scale, height: ink.height * scale),
      Paint()..filterQuality = FilterQuality.high,
    );
    final trimmed = await recorder.endRecording().toImage(_size, _size);
    image.dispose();
    return trimmed;
  }

  static Future<void> _paintTapback(Canvas canvas, Rect bounds, String type) async {
    final svg = await vg.loadPicture(SvgAssetLoader('assets/reactions/$type-black.svg'), null);
    final scale = _size / svg.size.longestSide;
    canvas.saveLayer(bounds, Paint());
    canvas.save();
    canvas.translate((_size - svg.size.width * scale) / 2, (_size - svg.size.height * scale) / 2);
    canvas.scale(scale);
    canvas.drawPicture(svg.picture);
    canvas.restore();
    // The glyph's own fill is replaced by its gradient, as TapbackIcon does
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: TapbackIcon.gradients[type]!,
        ).createShader(bounds),
    );
    canvas.restore();
    svg.picture.dispose();
  }

  static void _paintText(Canvas canvas, String emoji, bool appleFont) {
    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontFamily: appleFont ? 'Apple Color Emoji' : null, fontSize: _size * 0.8, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final scale = _size / painter.size.longestSide;
    canvas.save();
    canvas.translate((_size - painter.width * scale) / 2, (_size - painter.height * scale) / 2);
    canvas.scale(scale);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    painter.dispose();
  }
}
