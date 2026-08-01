# Theming and Components

Reference for the app's reusable custom widgets: standardized `Scaffold`/`AppBar`/`Chip`
wrappers and the shared skin-aware dialog builders. Use these instead of raw Flutter/Material/
Cupertino equivalents wherever they exist — they bake in the app's theming, platform, and
skin conventions so individual screens don't have to re-derive them.

See [Theming](#theming) below for how color, skin, and window-effect state actually flow into
these components.

## `BBScaffold`

`lib/app/wrappers/bb_scaffold.dart`

Drop-in replacement for `Scaffold`. Wraps the result in `BBAnnotatedRegion` and handles:

- **Background color** — defaults to transparent when a desktop window effect (Mica/acrylic)
  is active, otherwise `Theme.of(context).colorScheme.surface`.
- **SafeArea** — applied to `body` only (never to the `Scaffold` itself, so the scaffold's
  background can still fill edge-to-edge, including the Android gesture-pill area).
  - `safeAreaTop` defaults to `false` (an `AppBar` usually handles the status bar inset).
  - `safeAreaBottom` defaults to `false` when immersive mode + `extendBodyBehindBottomPill`
    are both active, `true` otherwise.
  - `safeAreaLeft` / `safeAreaRight` default to `true`.
- **Edge-to-edge Android** — `extendBodyBehindBottomPill` (maps to `Scaffold.extendBody`)
  defaults to `true`.

All other constructor params (`appBar`, `floatingActionButton`, `bottomNavigationBar`,
`drawer`, `endDrawer`, `bottomSheet`, `persistentFooterButtons`, etc.) pass straight through
to the underlying `Scaffold`.

```dart
@override
Widget build(BuildContext context) {
  return BBScaffold(
    appBar: BBAppBar(titleText: 'My Page'),
    body: YourContent(),
  );
}
```

## `BBAppBar`

`lib/app/wrappers/bb_app_bar.dart`

Drop-in replacement for `AppBar`. Implements `PreferredSizeWidget`, so it can be passed
directly to `Scaffold.appBar` (or `BBScaffold.appBar`) without a `PreferredSize` wrapper.

Baked-in defaults:

| Property | Default |
|---|---|
| `elevation` | `0` (always, not overridable) |
| `scrolledUnderElevation` | `3.0` |
| `backgroundColor` | `context.headerColor` |
| `centerTitle` | `context.iOS` |
| `surfaceTintColor` | `context.theme.colorScheme.primary` |
| `toolbarHeight` | `80.0` on desktop, `50.0` on mobile |
| `automaticallyImplyLeading` | `false` |
| `systemOverlayStyle` | derived from the effective background color's brightness |

Use `titleText` for the common case of a plain string title (styled with `titleStyle`,
defaulting to `context.theme.textTheme.titleLarge`). Pass a custom `title` widget only when
you need something beyond plain text — `title` takes precedence over `titleText` if both are
given.

```dart
appBar: BBAppBar(
  titleText: 'Settings',
  leading: buildBackButton(context),
  actions: [IconButton(...)],
),
```

## `BBChip`

`lib/app/components/bb_chip.dart`

Wraps `RawChip` with the app's standard chip styling: rounded-rectangle shape
(`borderRadius: 20`), and a subtle outline border (`context.theme.colorScheme.outline` at
10% opacity). Supports the same deletable/selectable modes as `RawChip`:

- Pass `onDeleted` to show a delete ("x") affordance.
- Pass `onSelected` + `selected` for a toggleable/filter chip; `showCheckmark` /
  `checkmarkColor` control the selection checkmark.
- `avatar` — leading widget (e.g. a contact avatar) before the label.
- `tapEnabled` / `onPressed` — plain tap behavior when not used as a selectable chip.

Used for things like filter chips and selected-contact tags in chat creation.

## `BBSwitch`

`lib/app/components/bb_switch.dart`

Skin-aware toggle: renders `CupertinoSwitch` under the iOS skin (`context.iOS`) and Material
`Switch` otherwise. Drop-in replacement for either — takes `value`, `onChanged`, and an optional
`activeColor` (mapped to `activeTrackColor` on the Cupertino side).

```dart
BBSwitch(
  value: someFlag,
  activeColor: context.theme.colorScheme.primary.lightenOrDarken(15),
  onChanged: (val) => setState(() => someFlag = val),
)
```

`SettingsSwitch` (`lib/app/layouts/settings/widgets/content/settings_switch.dart`) uses this
internally, so every settings toggle built on top of it is skin-aware for free. Prefer `BBSwitch`
over raw `Switch`/`CupertinoSwitch` for any new toggle outside of `SettingsSwitch`.

## Dialogs (`dialog_helpers.dart`)

`lib/helpers/ui/dialog_helpers.dart`

All dialog helpers are **skin-aware**: they render a `CupertinoAlertDialog` /
`CupertinoActionSheet` / `CupertinoPicker` on the iOS skin, and a Material `AlertDialog` on
Material/Samsung skins, based on `SettingsSvc.settings.skin.value`. Prefer these over
building `AlertDialog`/`CupertinoAlertDialog` directly in feature code.

### `showBBDialog<T>()`

General-purpose skin-aware alert dialog.

```dart
final result = await showBBDialog<bool>(
  context: context,
  title: 'Delete conversation?',
  body: 'This cannot be undone.',
  actions: [
    BBDialogAction(text: 'Cancel', onPressed: () => Navigator.pop(context)),
    BBDialogAction(text: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context, true)),
  ],
);
```

- Supply `body` (a plain string) or `content` (a custom `Widget`) — `content` wins if both
  are given.
- `bodyTextAlign` applies to `body` and is exposed to `content` via `DefaultTextStyle` so
  custom content can opt in.
- `actions` is a list of `BBDialogAction`:
  - `isDestructive` — iOS only, renders the action text in red.
  - `isDefault` — iOS only, renders the action text bold (the primary/default action).
  - `color` — Material/Samsung only, overrides the action text color.

### `showAreYouSure()`

Convenience wrapper around `showBBDialog` for a simple yes/no confirmation. Prefer this over
the deprecated `areYouSure` helper.

```dart
showAreYouSure(
  context,
  title: 'Are you sure?',
  onYes: () => doTheThing(),
  onNo: () {},
);
```

### `showBBListSelector<T>()`

Skin-aware single-selection list dialog.

- Material/Samsung: renders as a `showBBDialog` with each `BBListSelectorOption` as a
  tappable `ListTile` row.
- iOS: controlled by `iosStyle` (`BBListSelectorIOSStyle`):
  - `actionSheet` (default) — a `CupertinoActionSheet`, one button per option. Use for a
    short list of discrete choices (e.g. "Remind me in...").
  - `wheel` — a scrolling `CupertinoPicker` inside a modal with Done/Cancel — use for
    date/time or other continuous-value selection.

`BBListSelectorOption.isDestructive` renders that option in red on the iOS action-sheet
style only.

### `BBProgressDialog`

A `Widget` (not a one-shot `show*` function) for displaying progress of a long-running
operation. Because it's a widget, callers typically rebuild it in place as progress advances
(e.g. inside an `Obx`, or via `setState`) rather than tearing it down and re-showing it.

- `progress` — a value in `[0, 1]`, or `null` for an indeterminate spinner/bar.
- `body` — replaces the progress indicator entirely when non-null (e.g. to show an error).
- `title` — update as progress advances (e.g. `"Syncing..."` → `"Done syncing!"`).
- `actions` — same `BBDialogAction` list as `showBBDialog`.

Renders a thin rounded progress bar (or `CupertinoActivityIndicator` when indeterminate) on
iOS, and a `LinearProgressIndicator` on Material/Samsung.

```dart
showDialog(
  context: context,
  builder: (_) => Obx(() => BBProgressDialog(
    title: 'Syncing messages...',
    progress: controller.progress.value,
  )),
);
```

## Related Custom Widgets

Other reusable widgets that override or extend stock Flutter behavior — see
`lib/app/components/custom/CLAUDE.md` for details:

| Widget | File |
|---|---|
| `CustomCupertinoAlertDialog` / `CupertinoDialogAction` | `custom_cupertino_alert_dialog.dart` — used internally by `dialog_helpers.dart` to fix text-scaling and add dark/light theming |
| Custom page transition | `custom_cupertino_page_transition.dart` |
| `CustomErrorBox` | `custom_error_box.dart` |
| Custom bouncing scroll physics | `custom_bouncing_scroll_physics.dart` |

See also `lib/app/wrappers/CLAUDE.md` and `lib/app/components/CLAUDE.md` for the full list of
wrapper/component widgets (avatars, theme switching, tablet split-view, etc.).

---

## Theming

How color, skin, and platform state actually reach a widget. `docs/ARCHITECTURE.md` (§UI
Architecture → Skin System) covers the *concept* of the 3-skin system and `ThemeSwitcher`'s
branching pattern; this section covers the concrete mechanics — services, extensions, and
data model — that the components above are built on.

### Two independent axes: skin vs. theme

BlueBubbles has two orthogonal theming axes that are easy to conflate:

- **Skin** (`Skins.iOS` / `Skins.Material` / `Skins.Samsung`) — controls *which widget shapes*
  render (Cupertino vs. Material dialogs/pages/scroll physics). Set via
  `SettingsSvc.settings.skin` (`Rx<Skins>`, default `Skins.iOS`).
- **Theme** (`ThemeStruct` — light/dark `ThemeData` + custom color/text extensions) — controls
  *colors and type scale*, independent of skin. A user can run the iOS skin with any color
  theme, or the Material skin with the OLED-black theme, etc.

Almost every "theme-aware" component in this app reads from both axes at once (e.g. `BBAppBar`
uses `context.iOS` for `centerTitle` but `context.theme.colorScheme` for coloring).

### Skins

- Enum: `enum Skins { iOS, Material, Samsung }` — `lib/helpers/types/constants.dart:120`.
- Setting: `SettingsSvc.settings.skin` — `lib/database/global/settings.dart:139`, persisted as
  `skin.value.index`.
- Branching widget: `ThemeSwitcher` (`lib/app/wrappers/theme_switcher.dart`) — takes
  `iOSSkin`/`materialSkin`/`samsungSkin` (Samsung falls back to `materialSkin` if omitted) and
  switches on `SettingsSvc.settings.skin.value` inside an `Obx`. Also exposes static helpers
  that branch the same way outside of a widget tree:
  - `ThemeSwitcher.buildPageRoute<T>()` — iOS gets `CustomCupertinoPageTransition` in a
    `PageRouteBuilder`; Material/Samsung get plain `MaterialPageRoute`.
  - `ThemeSwitcher.getScrollPhysics()` (also exposed as `ThemeSvc.scrollPhysics`) — iOS gets
    `CustomBouncingScrollPhysics`; Material/Samsung get `ClampingScrollPhysics`.
- Quick boolean checks — two equivalent definitions, pick whichever fits the call site:
  - `ThemeHelpers` mixin (`lib/helpers/ui/theme_helpers.dart`), mixed into `CustomState` — gives
    `iOS` / `material` / `samsung` directly inside a state class.
  - `BuildContextThemeHelpers` extension on `BuildContext` (same file) — gives `context.iOS` /
    `context.material` / `context.samsung` anywhere a `BuildContext` is available.

### `ThemeSvc` (`lib/services/ui/theme/themes_service.dart`)

`ThemeSvc` (GetIt singleton, class `ThemesService`) owns theme selection, presets, and
light/dark switching. Key surface:

- `ThemeSvc.inDarkMode(context)` — reads `AdaptiveTheme.maybeOf(context)?.mode`; falls back to
  `PlatformDispatcher.instance.platformBrightness` if there's no `AdaptiveTheme` ancestor.
  `AdaptiveThemeMode.system` counts as dark only if the platform brightness is dark. **Use
  this, not `MediaQuery.platformBrightnessOf`, for any dark-mode branch** — it's the one
  consistent with the user's actual in-app theme mode override (light/dark/system).
- `ThemeSvc.changeTheme(context, {light, dark})` — persists the selected `ThemeStruct`s
  (`PrefsSvc.theme.setSelectedThemes(...)`), reloads them, applies Windows-accent
  post-processing (see below), then calls `AdaptiveTheme.of(context).setTheme(...)`.
- `ThemeSvc.revertToPreviousDarkTheme()` / `revertToPreviousLightTheme()` — restore the last
  theme before the current one (falls back to `"OLED Dark"` / `"Bright White"`).
- `ThemeSvc.isGradientBg(context)` — whether the active theme's `ThemeStruct.gradientBg` flag
  is set, consumed by `gradient_background_wrapper.dart`.
- `ThemeSvc.skin` — passthrough to `SettingsSvc.settings.skin.value`.

**Bundled presets** (`ThemeSvc.defaultThemes`) include:
- `"Bright White"` / `"OLED Dark"` — hand-built `FlexColorScheme` themes. OLED Dark uses a
  genuinely black surface (`ColorScheme.fromSeed(seedColor: Colors.blue, surface: Colors.black, ...)`)
  for true black-pixel-off OLED screens, not just a dark-gray Material dark theme.
  Bright White uses a light `ColorScheme.fromSeed` variant instead.
- 9 **Material You** variants (`base`, `vibrant`, `expressive`, `soft`, `neutral`, `lagoon`,
  `sunset`, `neonPop`, `earthy`) × light/dark — pulled from the OS/desktop dynamic-color
  palette (`DynamicColorPlugin.getCorePalette()`) and tuned per-variant via HSL adjustments in
  `ThemeSvc.materialYouTheme()`. Falls back to `oledDarkTheme`/`whiteLightTheme` if no dynamic
  palette is available on the platform.
- `"Nord Theme"` — static Nordic blue-gray palette (`#5E81AC` primary, `#88C0D0` accent).
- `"Music Theme ☀"` / `"Music Theme 🌙"` — placeholders overwritten at runtime by
  `updateMusicTheme()`, which derives a `ColorScheme.fromImageProvider` from the currently
  playing track's album art.
- Every non-custom `FlexScheme` value (light + dark) from the `flex_color_scheme` package.
- **Adaptive per-chat backgrounds** — `ThemeSvc.generateAdaptiveThemesFromImage(imagePath)`
  extracts a dominant color from a chat's custom background image and generates all 9
  Material You variant pairs from it, cached and persisted as `ThemeStruct`s named
  `__adaptive_background_theme__::<scope>::<light|dark>::<variant>`.
- **Windows accent color** — gated behind `Platform.isWindows` and
  `SettingsSvc.settings.useDesktopAccent`, `ThemeSvc._applyWindowsAccent()` harmonizes
  secondary/tertiary/error/surface colors toward the OS accent color via
  `Color.harmonizeWith()` (keeps hue, nudges toward target), while overwriting the primary
  channel outright.

Users can also build fully custom themes via the in-app Theme Studio
(`lib/app/layouts/settings/pages/theming/theme_studio/`), which edits a `ThemeStruct` directly.

### Color access patterns

Most of this lives in `lib/helpers/ui/theme_helpers.dart`.

**Base Theme.of(context) shortcuts** — `context.theme`, `context.colorScheme`,
`context.textTheme` are provided by the `get` (GetX) package's own `BuildContext` extension,
not custom code — they're thin `Theme.of(context)` wrappers, used pervasively per
`frontend.md`. Prefer them over spelling out `Theme.of(context)....` directly.

**`HexColor`** — `HexColor("#RRGGBB")` / `HexColor("#AARRGGBB")` converts a hex string to a
`Color`. 6-char strings are treated as opaque (`"FF"` alpha is prepended automatically).

**`BubbleColors`** — a `ThemeExtension<BubbleColors>` with fields `iMessageBubbleColor` /
`oniMessageBubbleColor`, `smsBubbleColor` / `onSmsBubbleColor`, `receivedBubbleColor` /
`onReceivedBubbleColor`. Every preset theme attaches its own instance so bubble colors can
diverge from the generic Material color scheme (e.g. OLED Dark's received-bubble is
near-black `#323332`; Bright White's is light gray `#e9e9ea`; Material You variants map
bubble colors straight to their tuned `primary`/`secondary`/`surfaceContainerHighest`).
Access via `Theme.of(context).extension<BubbleColors>()` — **never hardcode bubble colors**.

**`ColorSchemeHelpers.bubble(context, iMessage)` / `.onBubble(context, iMessage)`** — the
actual call sites should use these, not the `BubbleColors` extension directly: they prefer the
theme's `BubbleColors` extension but fall back to an algorithmic guess
(`iMessageBubble`/`smsBubble` getters on `ColorScheme`) for themes that don't define one (e.g.
Nord, or legacy/custom `FlexScheme` presets). The fallback picks whichever of
`primary`/`primaryContainer` is *less* "colorful" (HSL saturation/lightness distance from
`(1.0, 0.5)`) for the iMessage (blue) bubble, and the more colorful one for SMS (green).

**`BubbleText`** — a second `ThemeExtension` with a single `bubbleText` `TextStyle`, sized
independently of the rest of the type scale (`ThemeStruct.defaultTextSizes["bubbleText"] = 15`)
so message-bubble text can be tuned without affecting body text elsewhere.

**`context.headerColor` / `context.tileColor`** — used for settings-page section headers vs.
tile backgrounds. Both invert their mapping when `Skins.Material` + dark mode are active
(`_reverseMapping`), and both reduce alpha (`20` for header, `100` for tile) whenever a desktop
window effect is active, so surfaces read as translucent under Mica/acrylic instead of opaque.
Identical logic exists twice: once as `context.headerColor`/`context.tileColor` (extension on
`BuildContext`) and once as `headerColor`/`tileColor` on the `ThemeHelpers` state mixin — use
whichever is already in scope.

**`toColorGradient(String? address)`** — deterministic 2-color gradient for contact avatars,
seeded from the character-code sum of the input (handle address), picked from 7 fixed
`HexColor` pairs. Null/empty input yields a neutral gray gradient. Used by
`ContactAvatarWidget` / `ContactAvatarGroupWidget` — don't invent new avatar coloring schemes.

**Other `Color` helpers** worth knowing about (all in `theme_helpers.dart`):
- `darkenAmount(double)` / `lightenAmount(double)` — HSL-lightness adjustment; this is the
  pattern behind `HexColor(handle!.color!).lightenAmount(0.02)` from `frontend.md`.
- `themeLightenOrDarken(context, [percent])` — direction chosen from `ThemeSvc.inDarkMode`
  rather than the color's own luminance.
- `themeOpacity(context)` — full opacity unless a window effect is active; see Window Effects
  below.
- `createMaterialColor(Color)` — builds a full 50–900 `MaterialColor` swatch from one seed
  color (used e.g. by the Nord theme's `ColorScheme.fromSwatch`).

### System UI overlay styling

`buildSystemUiOverlayStyle()` (`lib/helpers/ui/system_ui_overlay_style_helpers.dart`) derives
status-bar/nav-bar icon brightness from a surface color via
`ThemeData.estimateBrightnessForColor()` unless told explicitly. In immersive mode, the nav
bar color/divider are forced transparent (`systemNavigationBarContrastEnforced: false`) — this
is what produces the transparent Android gesture-pill look.

`context.systemUiOverlayStyle()` (extension in `theme_helpers.dart`) is the app-specific entry
point: it supplies `surfaceColor: context.theme.colorScheme.surface` and
`immersiveMode: SettingsSvc.settings.immersiveMode.value` automatically. `BBAnnotatedRegion`
(`lib/app/wrappers/bb_annotated_region.dart`) wraps its child in an
`AnnotatedRegion<SystemUiOverlayStyle>` using this, and **`BBScaffold` wraps every screen in
`BBAnnotatedRegion`** — so any screen built on `BBScaffold` gets correct status/nav bar styling
for free; don't add a manual `AnnotatedRegion` on top of it.

### Window effects (desktop: Mica / Acrylic / Aero / transparent)

`lib/utils/window_effects.dart` (`WindowEffects`) wraps `flutter_acrylic`'s effects, gated to
`kIsDesktop && Platform.isWindows` and to the Windows build number that actually supports each
effect (e.g. Mica requires build ≥ 22000 / Windows 11). Setting: `SettingsSvc.settings.windowEffect`
(`Rx<WindowEffect>`, default `WindowEffect.disabled`), applied via
`WindowEffects.setEffect(color: context.theme.colorScheme.surface)` — called from `main.dart`
whenever the resolved theme changes.

Effect-dependent behavior components must account for:
- **Mica / Tabbed** depend on window *brightness* only — the OS paints the material, so
  widgets should stay fully opaque (`themeOpacity` returns `0.0` for these, meaning "don't
  paint your own overlay tint").
- **Aero / Acrylic / Transparent** depend on a *color* — `dependsOnColor()` is true, and
  `ColorHelpers.themeOpacity(context)` returns the user-configured
  `windowEffectCustomOpacityLight`/`windowEffectCustomOpacityDark` (default `0.5`) for widgets
  that need to paint a semi-transparent tint themselves.

Consuming components:
- **`BBScaffold`** — `backgroundColor` becomes fully `Colors.transparent` whenever
  `windowEffect.value != WindowEffect.disabled`, letting the native compositor's material show
  through; otherwise falls back to `context.theme.colorScheme.surface`.
- **`context.headerColor` / `context.tileColor`** — alpha drops to `20`/`100` (of 255) under
  any active window effect, so settings tiles look translucent over Mica/acrylic instead of a
  solid rectangle.
- If you add a new component that needs a background under Mica/acrylic, use
  `ColorHelpers.themeOpacity(context)` rather than hardcoding an opacity — it already encodes
  which effects need a manual tint vs. which are handled by the OS.

### How `ThemeData` / `ColorScheme` get built (and where user choices live)

- **Bootstrap**: `main.dart` loads `ThemeStruct.getLightTheme().data` /
  `.getDarkTheme().data` before `runApp`, applies Windows-accent post-processing
  (`ThemeSvc.getStructsFromData`), and wraps the app in `AdaptiveTheme(light:, dark:, initial:)`
  from the `adaptive_theme` package — this is the layer that owns the persisted
  light/dark/system mode toggle (independent from *which* light/dark `ThemeStruct` is
  selected). `GetMaterialApp`'s `theme`/`darkTheme` then read from the resolved
  `AdaptiveTheme` state, with `appBarTheme.elevation = 0.0` and a custom `DialogThemeData`
  forced on top (barrier = `colorScheme.shadow` @ 60% alpha, background =
  `colorScheme.surfaceContainerHighest` — this is why `showBBDialog`'s Material path doesn't
  need to set its own barrier/background).
- **Persistence entity**: `ThemeStruct` (`lib/database/io/theme.dart`, `@Entity()`) — `name`
  (unique), `gradientBg`, `googleFont`, and `data` (a `ThemeData`, serialized to/from JSON for
  ObjectBox — encodes the full `textTheme`, every M3 `colorScheme` role, and the
  `BubbleColors`/`BubbleText` extensions). `isPreset` is true if the name matches a built-in
  preset or an adaptive-background theme name. `getLightTheme()`/`getDarkTheme()` resolve the
  user's current selection (`PrefsSvc.theme.getSelectedLightTheme()/getSelectedDarkTheme()`,
  defaulting to `"Bright White"`/`"OLED Dark"`), cloning the static preset if no DB row exists
  yet. The older `ThemeObject` (`lib/database/io/theme_object.dart`) is
  `@Deprecated('Use ThemeStruct instead')` — don't build against it.
- **Construction strategy** is a blend, not one single approach: hand-authored
  `FlexColorScheme`/`ColorScheme.fromSeed` presets, real OS dynamic-color (Material You)
  palettes run through custom HSL tuning, every `flex_color_scheme` package preset, and
  fully user-authored themes from the in-app Theme Studio — all normalized into the same
  `ThemeStruct` shape so the rest of the app never needs to know which strategy produced a
  given theme.

### Practical checklist for a new themed component

1. Read colors from `context.theme.colorScheme` / `Theme.of(context).extension<BubbleColors>()`
   — never hardcode hex values (see `frontend.md`).
2. If it's a message bubble or bubble-adjacent element, use
   `context.theme.colorScheme.bubble(context, isIMessage)` / `.onBubble(...)`, not raw
   `colorScheme.primary`.
3. If it branches on light/dark, use `ThemeSvc.inDarkMode(context)`, not
   `MediaQuery.platformBrightnessOf(context)`.
4. If it branches on widget shape/behavior (not just color), use `context.iOS` /
   `context.material` / `context.samsung` or wrap variants in `ThemeSwitcher`.
5. If it paints its own background and might sit over a desktop window effect, use
   `ColorHelpers.themeOpacity(context)` instead of a fixed opacity.
6. Build it on `BBScaffold`/`BBAppBar` so status bar, nav bar, and window-effect handling come
   for free instead of being re-implemented per screen.
