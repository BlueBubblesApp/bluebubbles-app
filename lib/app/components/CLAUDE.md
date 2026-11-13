# lib/app/components/ — Reusable UI Components

## Avatars (`avatars/`)
- `contact_avatar_widget.dart` — single contact avatar (initials, photo, gradient color, typing indicator)
- `contact_avatar_group_widget.dart` — stacked multi-contact avatar for group chats

Every avatar file is drawn and precached through `ContactAvatarWidget.avatarImage(path)`: decoded to fit within
`ContactAvatarWidget.avatarDecodeSize` (256 px) keeping its aspect ratio, group photos included. Never draw one with a bare
`FileImage` or an exact-size resize (that squashes non-square photos), and use the same provider in the conversation list
warm-up or its precache is never hit. Chat backgrounds go through `wallpaper/static_wallpaper_image.dart` for the same reason: decoded at window
size, one provider shape for draw and precache, and left in the cache on close so reopening is instant. On desktop the
wrapper (`GradientBackground`) debounces the window size it decodes for, so a drag-resize reuses the existing decode and
only re-decodes once the window has held still.

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
- `copy_address_button.dart` — `CopyAddressButton`, skin-aware copy icon for a handle address (check mark + "Copied" feedback). Used on participant tiles and the 1:1 details header
- `custom_text_editing_controllers.dart` — `TextEditingController` subclasses for spellcheck and mentions in the message composer. `MentionTextEditingController` keeps the real text (a mention is the bare name, no `@`) plus `runs`: `Run`s in UTF-16 offsets that shift with each edit. Editing inside a mention turns it back into plain text. Bold/italic/underline/strikethrough and text effects are runs too (`toggleStyle`/`setEffect`, from `FormattingBar`, Ctrl+B/I/U, Ctrl+Shift+X; effect runs are drawn transparent and animated by `TextEffectOverlay`); typing at the end of formatted text extends its styles; an effect only goes on selected text, is never typed, and text typed inside an effect run splits it (both sides keep the effect), and `OutgoingMessageHandler.sendMultipart` sends each part's styles and effect as the server's `textFormatting`. Copying (selection menu, Ctrl+C/X, a message's Copy) also stores `{text, runs}` in the static `richClipboard`, since the system clipboard is plain text; a paste whose text matches gets those runs back (mentions only for people in the chat), and any other paste through `pasteText` lands plain instead of extending the formatting next to it. `attributedRuns` turns `runs` into a sendable attributed body; drafts store them in `Chat.textFieldRuns`, and drafts from the old `U+FFFC index U+FFFC` format are converted on load
- `sliver_decoration.dart` — decorative header for `CustomScrollView` / `SliverAppBar`

## Material 3 Expressive (`m3e/`)
Opt-in Material-3-Expressive primitives (shape scale, spacing scale, motion tokens, tonal section
containment, list tile, tonal button, button group) used by the **Material and Samsung** skins only
— leaf-level, skin-agnostic building blocks. Import via barrel:
`package:bluebubbles/app/components/m3e/m3e.dart`.

`M3EShapes` is corner radii; `M3ESpacing` is padding/gaps. They are separate scales that share
several values today — never feed a shape token to an `EdgeInsets` or a `SizedBox`, or retuning a
corner silently reflows layout.

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
