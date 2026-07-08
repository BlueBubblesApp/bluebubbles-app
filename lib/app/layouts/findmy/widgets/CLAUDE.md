# findmy/widgets/ — Find My UI Widgets

Sub-widgets for the Find My device/friends/items tracking screen.

## Files

| File | Purpose |
|------|---------|
| `findmy_map_widget.dart` | Interactive map with device/friend/self markers and popups |
| `findmy_devices_tab_view.dart` | Tab content listing the user's own Apple devices |
| `findmy_friends_tab_view.dart` | Tab content listing shared-location friends |
| `findmy_items_tab_view.dart` | Tab content listing AirTag / Find My accessory items |
| `findmy_device_list_tile.dart` | Single device row: icon, name, last-seen location and timestamp |
| `findmy_friend_list_tile.dart` | Single friend row: avatar, name, location, battery |
| `findmy_raw_data_dialog.dart` | Debug dialog showing raw JSON payload for a selected item |

## Related
- Parent view: `../CLAUDE.md` (findmy)
- Find My controller: `../findmy_controller.dart`
- HTTP endpoint: `lib/services/network/http_service.dart` → Find My API calls
