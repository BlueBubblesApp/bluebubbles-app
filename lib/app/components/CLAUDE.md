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
- `circle_progress_bar.dart` — circular progress indicator
- `custom_text_editing_controllers.dart` — `TextEditingController` subclasses for mention detection and rich formatting in the message composer
- `sliver_decoration.dart` — decorative header for `CustomScrollView` / `SliverAppBar`

## Material 3 Expressive (`m3e/`)
Opt-in Material-3-Expressive primitives (shape scale, motion tokens, tonal section containment,
list tile, tonal button, button group) used by the **Material and Samsung** skins only — leaf-level,
skin-agnostic building blocks. Import via barrel: `package:bluebubbles/app/components/m3e/m3e.dart`.

## Charts (`charts/`)
Thin `fl_chart` wrappers and stat-display primitives, shared across any feature that needs simple
data visualization. Import via barrel: `package:bluebubbles/app/components/charts/charts.dart`.
- `donut_chart.dart` — `DonutChart`/`DonutSlice`, pie/donut with built-in percent legend
- `stat_tile.dart` — `StatTile`/`StatTileGrid`, responsive KPI tile grid
- `section_skeleton.dart` — `SectionSkeleton`, shimmer loading placeholder
- `legend_grid.dart` — `LegendGrid`, color-swatch + label legend
