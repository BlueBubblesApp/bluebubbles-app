# Frontend Rules — Flutter UI

## Widget Base Classes

**With a GetX controller → use `CustomStateful` + `CustomState`**
```dart
class MyWidget extends CustomStateful<MyController> {
  const MyWidget({super.key, required super.parentController});
  State<StatefulWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends CustomState<MyWidget, void, MyController> {
  @override
  void initState() {
    super.initState();
    tag = controller.someId; // stable ID for controller lookup
    forceDelete = false;     // set true only if this widget owns the controller lifecycle
  }
}
```

**Plain stateless widget** → use `StatelessWidget` as normal. No special base needed.

## Controller Lifecycle

- Tag controllers with a **stable, unique ID** (e.g., chat GUID). Never use `randomString()` for permanent controllers.
- Use `randomString()` only for temporary instances (e.g., select-mode overlays).
- Set `permanent: true` on desktop/web: `Get.put(ctrl, tag: id, permanent: kIsDesktop || kIsWeb)`.
- Check before creating: `Get.isRegistered<MyController>(tag: id) ? Get.find() : Get.put(...)`.
- In list items: always set `forceDelete = false` so the parent list controls lifecycle.

## Reactive UI — Obx

- Wrap the **smallest subtree** that actually reads reactive values, not the entire screen.
- Nest a second `Obx()` inside when an inner subtree reads a different set of observables.
- Never read `.value` outside of `Obx()` or `GetBuilder` — you won't get updates.
- Prefer `Obx()` over `GetBuilder` unless you need manual `update()` control.

## State Classes (ChatState / MessageState pattern)

- Observable properties go in `ChatState` / `MessageState`, not on the DB entity itself.
- All service-driven mutations use `updateXxxInternal()` methods — widgets never write state directly.
- Always equality-check before assigning: `if (field.value != value) field.value = value;`.
- Derived booleans (e.g., `hasError`, `isSent`) are kept in sync inside the same update method.

## Caching Expensive Values

- Cache computed values in `_cached*` instance fields (colors, initials, avatar paths).
- Populate in `initState()` and refresh in `didUpdateWidget()` when relevant props change:
```dart
@override
void didUpdateWidget(MyWidget old) {
  super.didUpdateWidget(old);
  if (old.handle?.id != widget.handle?.id) _updateCachedValues();
}
```
- Read from cache in `build()`, never recompute inline.

## Platform-Specific Widget Trees

Use `ThemeSwitcher` to branch on skin setting:
```dart
ThemeSwitcher(
  iOSSkin:      CupertinoMyWidget(parentController: controller),
  materialSkin: MaterialMyWidget(parentController: controller),
  samsungSkin:  SamsungMyWidget(parentController: controller),
)
```

Check platform booleans (`kIsDesktop`, `kIsWeb`, `kIsIOS`) for layout branches, not user-agent strings.

## Theme & Color Access

```dart
// Color scheme
context.theme.colorScheme.primary
context.theme.colorScheme.outline.withValues(alpha: 0.85)

// Text styles
context.theme.textTheme.bodyMedium
context.theme.textTheme.titleLarge

// Dark mode check
ThemeSvc.inDarkMode(context)

// Skin shortcuts (from ThemeHelpers mixin)
iOS       // bool — current skin is Cupertino
material  // bool — current skin is Material
samsung   // bool — current skin is Samsung
```

Never hardcode color hex values — always derive from `context.theme`.

- Message bubbles: use `ColorSchemeHelpers.bubble(context, isIMessage)` / `.onBubble(...)` —
  never read `colorScheme.primary`/`secondary` directly for bubble coloring.
- Dark-mode branches: use `ThemeSvc.inDarkMode(context)`, not `MediaQuery.platformBrightnessOf` —
  it's the one that respects the user's light/dark/system override.

## Reusable Components

Prefer these over raw Flutter/Material/Cupertino equivalents — they bake in this app's
theming, platform, and skin conventions. Full reference: `docs/THEMING_AND_COMPONENTS.md`.

| Instead of | Use | File |
|---|---|---|
| `Scaffold` | `BBScaffold` | `lib/app/wrappers/bb_scaffold.dart` |
| `AppBar` | `BBAppBar` | `lib/app/wrappers/bb_app_bar.dart` |
| `RawChip` | `BBChip` | `lib/app/components/bb_chip.dart` |
| `Switch` / `CupertinoSwitch` | `BBSwitch` | `lib/app/components/bb_switch.dart` |
| `AlertDialog` / `CupertinoAlertDialog` | `showBBDialog<T>()`, `showAreYouSure()`, `showBBListSelector<T>()`, `BBProgressDialog` | `lib/helpers/ui/dialog_helpers.dart` |

Dialog helpers are skin-aware (Cupertino on iOS skin, Material on Material/Samsung) — don't
branch on skin manually when one of these already exists.

## Avatars

- Single contact: `ContactAvatarWidget`
- Group: `ContactAvatarGroupWidget`
- Color gradient from address: `toColorGradient(handle?.address)`
- Custom color override: `HexColor(handle!.color!).lightenAmount(0.02)`

## Naming Conventions

| Thing | Pattern | Example |
|-------|---------|---------|
| Controller | `[Feature]Controller` | `ConversationTileController` |
| State class | `_[Widget]State` | `_ConversationTileState` |
| Observable wrapper | `[Model]State` | `ChatState`, `MessageState` |
| Tile widget | `[Feature]Tile` | `RedactedModeTile` |
| Sub-widget | `[Role][Parent]` | `ChatTitle`, `ChatSubtitle` |
| Cached field | `_cached[Name]` | `_cachedColors`, `_cachedInitials` |
| Internal updater | `update[Field]Internal` | `updateIsPinnedInternal` |

## Settings Tiles

Use widgets from `lib/app/layouts/settings/widgets/tiles/` as building blocks — don't build custom setting rows from scratch.
