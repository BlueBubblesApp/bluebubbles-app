# findmy/ — Find My Device Locator

## Files
- `findmy_page.dart` — `FindMyPage`, opened full-window by `NavigationSvc.openFindMy()`: lists and map in a split of their own, or the map with a sliding list panel on a phone
- `findmy_controller.dart` — state and logic: location polling, device/friend tracking
- `findmy_location_clipper.dart` — custom `CustomClipper` for location shape
- `findmy_pin_clipper.dart` — custom `CustomClipper` for map pin shape

## Widgets (`widgets/`)
- `findmy_map_widget.dart` — interactive map view
- `findmy_friend_list_tile.dart` — friend location list row
- `findmy_device_list_tile.dart` — device location list row
- `findmy_items_tab_view.dart` — tracked items tab
- `findmy_devices_tab_view.dart` — devices tab
- `findmy_friends_tab_view.dart` — friends tab
- `findmy_raw_data_dialog.dart` — debug view of raw location payload

## Data Models
`lib/database/global/findmy_friend.dart`
`lib/database/global/findmy_device.dart`
