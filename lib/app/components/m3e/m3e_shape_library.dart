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
  /// Relative likelihood of each avatar shape.
  ///
  /// Two measured signals, not taste. **Area** is the fraction of the avatar box
  /// the normalized shape actually fills (shoelace over a dense sampling of its
  /// path) — it's what makes a tile read as full-size rather than shrunken next
  /// to its neighbours. **Round** is the smallest corner-rounding radius in the
  /// upstream `MaterialShapes` definition — the larger, the softer the outline.
  ///
  /// Weight starts from an area bucket (>=0.78 -> 5, >=0.65 -> 4, >=0.58 -> 3,
  /// else 2) and is then docked for hard corners: -1 for a corner under ~0.17,
  /// -2 under 0.10, -3 for true right angles. Floor of 1, so nothing is gated
  /// out — this biases the draw, it doesn't restrict it.
  ///
  /// Measuring beats eyeballing here: `puffy` looks plump but fills only 0.586,
  /// `pixelCircle` fills 0.827 despite its stair-steps, and `softBurst` rounds
  /// its points harder than `sunny` does in spite of the name.
  ///
  /// Restricted to the roughly radially symmetric shapes so a face centred in
  /// the source image stays centred. The rest of the library is still reachable
  /// by id — `heart`, `arch` and `ghostish` just put the visual weight well off
  /// centre, `pill` and `oval` leave a square box half empty, and `burst` /
  /// `boom` (rounding 0.006, area as low as 0.353) shred a contact photo.
  static const Map<M3EShapeId, int> _avatarShapeWeights = {
    //                          weight    area   round
    M3EShapeId.square: 5, //              0.923  0.189 smoothed
    M3EShapeId.slanted: 5, //             0.828  0.187 smoothed
    M3EShapeId.clover4Leaf: 5, //         0.788  0.476
    M3EShapeId.circle: 5, //              0.785  n/a
    M3EShapeId.gem: 4, //                 0.729  0.208
    M3EShapeId.cookie12Sided: 4, //       0.692  0.50
    M3EShapeId.cookie9Sided: 4, //        0.687  0.50
    M3EShapeId.clover8Leaf: 4, //         0.684  0.209
    M3EShapeId.cookie4Sided: 4, //        0.678  0.233
    M3EShapeId.cookie7Sided: 4, //        0.661  0.50
    M3EShapeId.cookie6Sided: 4, //        0.659  0.394
    M3EShapeId.pentagon: 3, //     4 -1   0.665  0.164
    M3EShapeId.sunny: 3, //        4 -1   0.651  0.085 on wide lobes
    M3EShapeId.softBoom: 3, //            0.617  0.174
    M3EShapeId.puffy: 3, //               0.586  0.405
    M3EShapeId.pixelCircle: 2, //  5 -3   0.827  hard right angles by design
    M3EShapeId.flower: 2, //       3 -1   0.596  0.095 on the inner notches only
    M3EShapeId.puffyDiamond: 2, //        0.567  0.146
    M3EShapeId.softBurst: 1, //    3 -2   0.605  0.053
    M3EShapeId.verySunny: 1, //    3 -2   0.596  0.085 on narrow lobes
    M3EShapeId.diamond: 1, //      2 -1   0.517  0.151
    M3EShapeId.triangle: 1, //     2 -1   0.513  0.20, but acute on a 3-gon
  };

  /// The distinct shapes [shapeForKey] can hand out, most-favoured first.
  static List<M3EShapeId> get avatarShapes => _avatarShapeWeights.keys.toList(growable: false);

  // Each shape repeated by its weight, so a single modulo does the biased draw.
  // Map literals keep insertion order, so this list is stable across runs.
  static final List<M3EShapeId> _weightedAvatarPool = [
    for (final entry in _avatarShapeWeights.entries) ...List.filled(entry.value, entry.key),
  ];

  /// Picks a stable shape for [key] (a chat GUID, a handle address, …).
  ///
  /// Deterministic and order-independent on purpose: a chat keeps its shape when
  /// the pinned list is reordered, when another chat is pinned, and across app
  /// restarts. FNV-1a rather than [Object.hashCode] so the mapping can't drift
  /// between platforms or SDK versions.
  static M3EShapeId shapeForKey(String key, {List<M3EShapeId>? from}) {
    // Defaults to the weighted pool; pass `from` for an unbiased draw over an
    // explicit list.
    final pool = from ?? _weightedAvatarPool;
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
