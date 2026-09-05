# lib/app/components/ — Reusable UI Components

## Avatars (`avatars/`)
- `contact_avatar_widget.dart` — single contact avatar (initials, photo, gradient color, typing indicator)
- `contact_avatar_group_widget.dart` — stacked multi-contact avatar for group chats

Always use these for any handle/contact avatar — don't build custom avatar UIs from scratch.
Color gradient from address: `toColorGradient(handle?.address)`. Custom color: `HexColor(handle!.color!)`.

## Custom Widgets (`custom/`)
- `custom_bouncing_scroll_physics.dart` — bouncy scroll physics for lists
- `custom_cupertino_page_transition.dart` — iOS-style push/pop page transition
- `custom_cupertino_alert_dialog.dart` — iOS-style alert dialog
- `custom_error_box.dart` — styled inline error display box

## Other Components
- `bb_chip.dart` — chip/tag widget (used for labels, selected contacts, etc.)
- `bb_switch.dart` — `BBSwitch`, skin-aware toggle (`CupertinoSwitch` on iOS skin, Material `Switch` otherwise). Used internally by `SettingsSwitch`; prefer it over raw `Switch`/`CupertinoSwitch` for any new toggle.
- `bb_slider.dart` — `BBSlider`, skin-aware slider (`CupertinoSlider` on iOS skin, Material 3 Expressive-styled `Slider` via `m3e/m3e_slider.dart` on Material/Samsung). Supports `divisions` (steps). Used internally by `SettingsSlider`; prefer it over raw `Slider`/`CupertinoSlider` for any new slider/number-picker.
- `circle_progress_bar.dart` — circular progress indicator
- `custom_text_editing_controllers.dart` — `TextEditingController` subclasses for mention detection and rich formatting in the message composer
- `sliver_decoration.dart` — decorative header for `CustomScrollView` / `SliverAppBar`

## Material 3 Expressive (`m3e/`)
Opt-in Material-3-Expressive primitives (shape scale, spacing scale, motion tokens, tonal section
containment, list tile, tonal button, button group) used by the **Material and Samsung** skins only
— leaf-level, skin-agnostic building blocks. Import via barrel:
`package:bluebubbles/app/components/m3e/m3e.dart`.

`M3EShapes` is corner radii; `M3ESpacing` is padding/gaps. They are separate scales that share
several values today — never feed a shape token to an `EdgeInsets` or a `SizedBox`, or retuning a
corner silently reflows layout.

`m3e_shape_library.dart` is the *abstract shape* library (cookie, clover, burst, gem, …), not the
corner scale. Geometry comes from the `material_new_shapes` package (a port of
`androidx.graphics.shapes`), so these are the real M3E spec shapes — don't hand-roll lookalikes.
- `M3EShapeLibrary.shapeForKey(guid)` — deterministic shape for a stable key (FNV-1a, not
  `hashCode`), so an entity keeps its shape across reorders, restarts and platforms. Draws from a
  weighted pool of the radially-symmetric shapes, biased toward large-area, soft-cornered ones —
  every shape can still come up, common ones just come up more. The weights are derived from two
  measured properties documented in `_avatarShapeWeights`; if you retune them, measure rather than
  eyeball (`puffy` looks plumper than it is, `pixelCircle` is larger). Pass `from:` for an
  unbiased draw over an explicit list.
- `M3EShapeBorder(shape: id)` — an `OutlinedBorder`, so clip, ink splash and outline all come from
  one object. Pass it to `Material.shape`, `InkWell.customBorder`, `ShapeDecoration.shape`, or
  `ContactAvatarWidget`/`ContactAvatarGroupWidget`'s `shape:` param.

`M3ETonalButton` takes a nullable `onPressed`; pass null for a busy/unavailable state rather than
an empty callback, and it handles the dimming, the inert ink, and the semantics.

`M3ESlider.themeData(context, ...)` returns a `SliderThemeData` (thick track, oversized thumb,
dotted step indicators) built from the active `ColorScheme` — consumed by `BBSlider`, not used
directly by feature code.

## Charts (`charts/`)
Thin `fl_chart` wrappers and stat-display primitives, shared across any feature that needs simple
data visualization. Import via barrel: `package:bluebubbles/app/components/charts/charts.dart`.
- `donut_chart.dart` — `DonutChart`/`DonutSlice`, pie/donut with built-in percent legend
- `stat_tile.dart` — `StatTile`/`StatTileGrid`, responsive KPI tile grid
- `section_skeleton.dart` — `SectionSkeleton`, shimmer loading placeholder
- `legend_grid.dart` — `LegendGrid`, color-swatch + label legend
