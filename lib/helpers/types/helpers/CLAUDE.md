# helpers/types/helpers/ — Type-Specific Utility Functions

Pure functions, no state or service dependencies.

## File Routing

| File | What's inside |
|------|---------------|
| `string_helpers.dart` | `randomString(n)` — generates n-char alphanumeric string (used for tempGuids); `sanitizeString()` strips U+FFFC; `sanitizeFileName()` / `hasReservedFileNameChars()` — make a foreign string safe as a file name (always run IDs/names through this before building a path); `isNullOrEmptyString()`; `parseLinks()` — extracts URLs via regex |
| `date_helpers.dart` | `buildDate(DateTime, {forceYearWhenOlderThan})` — human-relative timestamps ("Just Now", "5 min", "Yesterday", "Mon 4:30") respecting 24-hour setting and chat skin |
| `message_helper.dart` | `MessageHelper.bulkAddMessages()` — offloads bulk message insertion to isolate via `MessageInterface`; reports progress via callback |
| `contact_helpers.dart` | Phone number formatting via `dlibphonenumber`; locale-aware country codes; email detection |
| `misc_helpers.dart` | `isNullOrEmpty(dynamic)` — null/blank/empty-collection check; `isNullOrZero()`; `mergeTopLevelDicts()` |

## Quick Reference

```dart
// Generate a temp GUID prefix (also used by Message.generateTempGuid())
final id = randomString(8);  // e.g. "a7d3k9m2"

// Format a message timestamp for display
final label = buildDate(message.dateCreated!);  // "Just Now" / "5 min" / "Yesterday" / etc.

// Null/empty guard used everywhere
if (isNullOrEmpty(value)) return;

// Format a phone number for display
final formatted = await formatPhoneNumber("+14155552671");  // "(415) 555-2671"
```
