import 'package:flutter/foundation.dart';

/// Where the sender put a sticker placed on a message part: an attachment's `stickerPlacement` from the server
@immutable
class StickerPlacement {
  final double xScalar;
  final double yScalar;
  final double scale;

  /// In radians, clockwise
  final double rotation;

  /// Width in points the sender drew the parent bubble at
  final double parentPreviewWidth;

  const StickerPlacement({
    required this.xScalar,
    required this.yScalar,
    required this.scale,
    required this.rotation,
    required this.parentPreviewWidth,
  });

  /// The placement in [json], or null when any of its values is missing or not a finite number,
  /// since a sticker can't be laid out from part of one
  static StickerPlacement? tryParse(Object? json) {
    if (json is! Map) return null;
    double? v(String key) {
      final value = json[key];
      final parsed = value is num ? value.toDouble() : (value is String ? double.tryParse(value.trim()) : null);
      return parsed != null && parsed.isFinite ? parsed : null;
    }

    final x = v('xScalar'), y = v('yScalar'), scale = v('scale'), rotation = v('rotation');
    final width = v('parentPreviewWidth');
    if (x == null || y == null || scale == null || rotation == null || width == null) return null;
    return StickerPlacement(xScalar: x, yScalar: y, scale: scale, rotation: rotation, parentPreviewWidth: width);
  }

  Map<String, dynamic> toMap() => {
        'xScalar': xScalar,
        'yScalar': yScalar,
        'scale': scale,
        'rotation': rotation,
        'parentPreviewWidth': parentPreviewWidth,
      };

  @override
  bool operator ==(Object other) =>
      other is StickerPlacement &&
      other.xScalar == xScalar &&
      other.yScalar == yScalar &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.parentPreviewWidth == parentPreviewWidth;

  @override
  int get hashCode => Object.hash(xScalar, yScalar, scale, rotation, parentPreviewWidth);
}
