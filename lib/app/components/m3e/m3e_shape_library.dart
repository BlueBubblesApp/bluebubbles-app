import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

/// Identifiers for the Material 3 Expressive abstract shape library.
///
/// M3 Expressive ships a library of 35 abstract shapes used as containers for
/// imagery and avatars in place of the plain circle / rounded rect. The geometry
/// comes from `material_new_shapes`, a port of `androidx.graphics.shapes`, so
/// these are the real spec shapes rather than lookalikes.
///
/// Names mirror `MaterialShapes` in that package.
enum M3EShapeId {
  circle,
  square,
  slanted,
  arch,
  semiCircle,
  oval,
  pill,
  triangle,
  arrow,
  fan,
  diamond,
  clamShell,
  pentagon,
  gem,
  sunny,
  verySunny,
  cookie4Sided,
  cookie6Sided,
  cookie7Sided,
  cookie9Sided,
  cookie12Sided,
  clover4Leaf,
  clover8Leaf,
  burst,
  softBurst,
  boom,
  softBoom,
  flower,
  puffy,
  puffyDiamond,
  ghostish,
  pixelCircle,
  pixelTriangle,
  bun,
  heart,
}

/// Resolves an [M3EShapeId] to its geometry.
///
/// Each shape is normalized by the upstream package into the unit square, so one
/// definition scales to any avatar size. Use [M3EShapeBorder] to hand a shape to
/// `Material`, `InkWell`, `ShapeDecoration` or `ClipPath` — clipping, ink
/// splashes and the optional outline then all read from the same path.
abstract final class M3EShapeLibrary {
  /// Shapes that read well as an avatar mask: roughly radially symmetric, so a
  /// face centred in the source image stays centred and reasonably uncropped.
  ///
  /// The rest of the library stays reachable by id — it's just that a `heart`,
  /// `arch` or `ghostish` mask puts the visual weight well off centre, `pill` and
  /// `oval` leave a square avatar box half empty, and the needle-thin points on
  /// `burst` / `boom` shred a contact photo (their soft variants don't).
  static const List<M3EShapeId> avatarShapes = [
    M3EShapeId.circle,
    M3EShapeId.square,
    M3EShapeId.slanted,
    M3EShapeId.triangle,
    M3EShapeId.diamond,
    M3EShapeId.pentagon,
    M3EShapeId.gem,
    M3EShapeId.sunny,
    M3EShapeId.verySunny,
    M3EShapeId.cookie4Sided,
    M3EShapeId.cookie6Sided,
    M3EShapeId.cookie7Sided,
    M3EShapeId.cookie9Sided,
    M3EShapeId.cookie12Sided,
    M3EShapeId.clover4Leaf,
    M3EShapeId.clover8Leaf,
    M3EShapeId.softBurst,
    M3EShapeId.softBoom,
    M3EShapeId.flower,
    M3EShapeId.puffy,
    M3EShapeId.puffyDiamond,
    M3EShapeId.pixelCircle,
  ];

  /// Picks a stable shape for [key] (a chat GUID, a handle address, …).
  ///
  /// Deterministic and order-independent on purpose: a chat keeps its shape when
  /// the pinned list is reordered, when another chat is pinned, and across app
  /// restarts. FNV-1a rather than [Object.hashCode] so the mapping can't drift
  /// between platforms or SDK versions.
  static M3EShapeId shapeForKey(String key, {List<M3EShapeId>? from}) {
    final pool = from ?? avatarShapes;
    if (pool.isEmpty) return M3EShapeId.circle;
    return pool[_fnv1a(key) % pool.length];
  }

  static int _fnv1a(String input) {
    // 32-bit FNV-1a, masked to stay inside the JS-safe integer range.
    int hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// The upstream polygon for [id]. Exposed for `Morph`-based animation, which
  /// needs the polygon rather than a flattened path.
  static RoundedPolygon polygon(M3EShapeId id) {
    switch (id) {
      case M3EShapeId.circle:
        return MaterialShapes.circle;
      case M3EShapeId.square:
        return MaterialShapes.square;
      case M3EShapeId.slanted:
        return MaterialShapes.slanted;
      case M3EShapeId.arch:
        return MaterialShapes.arch;
      case M3EShapeId.semiCircle:
        return MaterialShapes.semiCircle;
      case M3EShapeId.oval:
        return MaterialShapes.oval;
      case M3EShapeId.pill:
        return MaterialShapes.pill;
      case M3EShapeId.triangle:
        return MaterialShapes.triangle;
      case M3EShapeId.arrow:
        return MaterialShapes.arrow;
      case M3EShapeId.fan:
        return MaterialShapes.fan;
      case M3EShapeId.diamond:
        return MaterialShapes.diamond;
      case M3EShapeId.clamShell:
        return MaterialShapes.clamShell;
      case M3EShapeId.pentagon:
        return MaterialShapes.pentagon;
      case M3EShapeId.gem:
        return MaterialShapes.gem;
      case M3EShapeId.sunny:
        return MaterialShapes.sunny;
      case M3EShapeId.verySunny:
        return MaterialShapes.verySunny;
      case M3EShapeId.cookie4Sided:
        return MaterialShapes.cookie4Sided;
      case M3EShapeId.cookie6Sided:
        return MaterialShapes.cookie6Sided;
      case M3EShapeId.cookie7Sided:
        return MaterialShapes.cookie7Sided;
      case M3EShapeId.cookie9Sided:
        return MaterialShapes.cookie9Sided;
      case M3EShapeId.cookie12Sided:
        return MaterialShapes.cookie12Sided;
      case M3EShapeId.clover4Leaf:
        return MaterialShapes.clover4Leaf;
      case M3EShapeId.clover8Leaf:
        return MaterialShapes.clover8Leaf;
      case M3EShapeId.burst:
        return MaterialShapes.burst;
      case M3EShapeId.softBurst:
        return MaterialShapes.softBurst;
      case M3EShapeId.boom:
        return MaterialShapes.boom;
      case M3EShapeId.softBoom:
        return MaterialShapes.softBoom;
      case M3EShapeId.flower:
        return MaterialShapes.flower;
      case M3EShapeId.puffy:
        return MaterialShapes.puffy;
      case M3EShapeId.puffyDiamond:
        return MaterialShapes.puffyDiamond;
      case M3EShapeId.ghostish:
        return MaterialShapes.ghostish;
      case M3EShapeId.pixelCircle:
        return MaterialShapes.pixelCircle;
      case M3EShapeId.pixelTriangle:
        return MaterialShapes.pixelTriangle;
      case M3EShapeId.bun:
        return MaterialShapes.bun;
      case M3EShapeId.heart:
        return MaterialShapes.heart;
    }
  }

  // toPath() walks and rounds every cubic in the polygon, so cache the unit-space
  // result — a pinned grid rebuilds on every unread/typing tick.
  static final Map<M3EShapeId, Path> _unitCache = {};

  /// The shape as a path inside the unit square. Cached — treat as immutable.
  static Path unitPath(M3EShapeId id) => _unitCache[id] ??= polygon(id).toPath();

  /// The shape scaled to fill [size].
  static Path path(M3EShapeId id, Size size) {
    return unitPath(id).transform(Matrix4.diagonal3Values(size.width, size.height, 1).storage);
  }
}

/// An [OutlinedBorder] backed by a shape from [M3EShapeLibrary].
///
/// Because it's a `ShapeBorder`, one instance covers clipping
/// (`Container.decoration` / `ClipPath`), the ink splash boundary
/// (`Material.shape`, `InkWell.customBorder`) and the outline — they can't drift
/// out of sync the way a separate clipper and painter would.
class M3EShapeBorder extends OutlinedBorder {
  const M3EShapeBorder({required this.shape, super.side = BorderSide.none});

  final M3EShapeId shape;

  /// Shapes are authored square, so a non-square rect stretches them — the same
  /// thing [BoxShape.circle] does in a non-square box.
  Path _path(Rect rect) => M3EShapeLibrary.path(shape, rect.size).shift(rect.topLeft);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.strokeOffset / 2)), side.toPaint());
  }

  @override
  M3EShapeBorder copyWith({BorderSide? side, M3EShapeId? shape}) =>
      M3EShapeBorder(shape: shape ?? this.shape, side: side ?? this.side);

  @override
  ShapeBorder scale(double t) => M3EShapeBorder(shape: shape, side: side.scale(t));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  bool operator ==(Object other) => other is M3EShapeBorder && other.shape == shape && other.side == side;

  @override
  int get hashCode => Object.hash(shape, side);
}
