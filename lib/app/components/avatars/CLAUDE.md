# app/components/avatars/ — Contact Avatar Widgets

Two widgets for rendering contact or group avatars throughout the app.

## Files

| File | Purpose |
|------|---------|
| `contact_avatar_widget.dart` | Single-contact avatar: shows profile photo if available, falls back to initials circle with `toColorGradient(handle.address)` gradient |
| `contact_avatar_group_widget.dart` | Group conversation avatar: stacks up to 4 individual `ContactAvatarWidget`s in a 2×2 or overlapping layout |

## Key Parameters (`ContactAvatarWidget`)
- `handle` — the `Handle` entity to render for
- `size` — diameter in logical pixels
- `borderThickness` — optional white border (use in list tiles)
- `customColor` — override gradient with `HexColor(handle.color!)`
- `shape` — optional `OutlinedBorder` replacing the circle (e.g. `M3EShapeBorder`); drives the
  fill, the clip, the ink splash and the border at once

## Shape Masks
`ContactAvatarGroupWidget` also takes `shape`, but applies it only to a chat's **custom group photo**
and to **single-participant** chats. The multi-avatar grid stays circular by design — it is already a
composition of circles against a circular frame, and masking it with a star or clover slices the
outer avatars in half.

## Usage
```dart
ContactAvatarWidget(handle: handle, size: 40)
ContactAvatarGroupWidget(chat: chat, size: 40)
```

## Color Derivation
- Default: `toColorGradient(handle.address)` (deterministic from address string)
- Custom: `HexColor(handle.color!).lightenAmount(0.02)` when `handle.color != null`

## Related
- Handle model: `lib/database/io/handle.dart`
- Color helper: `lib/utils/color_engine/CLAUDE.md`
