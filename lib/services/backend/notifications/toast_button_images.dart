import 'dart:async';
import 'dart:typed_data';
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
  static const int _version = 3;

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
      final png = await draw(action, appleFont: emojiFont);
      if (png == null) return null;
      await file.create(recursive: true);
      await file.writeAsBytes(png);
      return file.path;
    } catch (e, s) {
      Logger.warn('Failed to draw toast button image for $action', error: e, trace: s, tag: 'ToastButtonImages');
      return null;
    }
  }

  /// The PNG [forAction] caches for [action], drawn with the Apple emoji font when [appleFont]
  static Future<Uint8List?> draw(String action, {required bool appleFont}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Offset.zero & const Size.square(_size + 0.0);
    // Named tapbacks are their icons, as on messages, so they don't look like the same emoji
    final named = ReactionTypes.toList().contains(action);
    if (named) {
      await _paintTapback(canvas, bounds, action);
    } else {
      _paintText(canvas, action, appleFont);
    }
    var image = await _trimmed(await recorder.endRecording().toImage(_size, _size));
    // Segoe UI Emoji has no flags and draws their letters as a white glyph, which Windows should theme for contrast
    final letterFlag =
        !appleFont && action.runes.length == 2 && action.runes.every((r) => r >= 0x1F1E6 && r <= 0x1F1FF);
    if (!letterFlag) image = await _withBackdrop(image);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png?.buffer.asUint8List();
  }

  /// [image] at 58px over a near-invisible backdrop filling the 64px image: a checkerboard of black and white pixels
  /// at 2/255 alpha. Windows themes images it takes for glyphs, inverting them against the notification's background:
  /// flat emoji (♥ 🔵 ⬛) and darker ones (emphasize) on light and accent backgrounds. It stops once enough backdrop
  /// shows around them. Tested on real notifications: at 60px ⬛ and 📈 were inverted, and 59px can't be centered on
  /// whole pixels. Both colors because each alone failed somewhere: over white, light emoji (☁ 🐰) were still
  /// inverted on light backgrounds; over black, 🚴 and 🍭 were on accent ones.
  static Future<ui.Image> _withBackdrop(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(const Color.fromARGB(2, 0, 0, 0), BlendMode.src);
    final white = Paint()
      ..color = const Color.fromARGB(2, 255, 255, 255)
      ..blendMode = BlendMode.src
      ..isAntiAlias = false;
    for (int y = 0; y < _size; y++) {
      for (int x = (y + 1) % 2; x < _size; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x + 0.0, y + 0.0, 1, 1), white);
      }
    }
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      // Whole pixels: a half-covered edge column was enough to get a flat black square (Apple ◼) inverted in dark mode
      const Rect.fromLTWH(3, 3, 58, 58),
      Paint()..filterQuality = FilterQuality.high,
    );
    final backed = await recorder.endRecording().toImage(_size, _size);
    image.dispose();
    return backed;
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
