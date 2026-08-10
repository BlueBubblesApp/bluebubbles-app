# helpers/types/extensions/ — Extension Methods

## Files
| File | Purpose |
|------|---------|
| `extensions.dart` | Barrel that exports all extension files; import this instead of individual extension files |

## What's Exported
Extension methods on: `String`, `DateTime`, `Color`, `List`, `int`, `Uint8List`, `Uri`, `BuildContext`, `Message`, `Chat`, `Handle`, `ThemeData`, and more.

Two worth knowing about because they're easy to reimplement badly:
- `Uri.hostMatches(domain)` / `Uri.hostMatchesAny(domains)` — subdomain-aware host matching. Compares label-wise, so `notyoutube.com` does not match `youtube.com`. Use this instead of a bare `endsWith`.
- `String.withoutInvisibleFormatting` — strips bidi overrides (RTL spoofing) and normalises non-breaking/zero-width spaces. Apply to any untrusted text before display or before a whitespace collapse.

## Usage
```dart
import 'package:bluebubbles/helpers/types/extensions/extensions.dart';
```

Imported via the `helpers.dart` barrel automatically when you import helpers.

## Related
- Constants (effect map, etc.): `../constants.dart`
- Type helper classes: `../classes/CLAUDE.md`
- Type helpers (date, message, etc.): `../helpers/CLAUDE.md`
