# conversation_list/ — Chat List / Inbox

## Pages (`pages/`)
- `conversation_list.dart` — main entry; uses `ConversationListController`
- `cupertino_conversation_list.dart` — iOS skin
- `material_conversation_list.dart` — Material skin
- `samsung_conversation_list.dart` — Samsung skin
- `search/search_view.dart` — full-text search results page (UI + filter state orchestration)
- `search/search_query_helper.dart` — local/network message search query execution and result hydration
- `search/search_models.dart` — typed search models (`SearchMode`, `SearchResultItem`)

## Widgets

**Header** (`widgets/header/`)
- `header_widgets.dart` — shared header components
- `material_header.dart`, `cupertino_header.dart`, `samsung_header.dart` — skin-specific headers

**Tile** (`widgets/tile/`) — individual chat row → CLAUDE.md inside
- `conversation_tile.dart` — base tile; controller setup and skin dispatch via `ThemeSwitcher`
- `material_conversation_tile.dart`, `cupertino_conversation_tile.dart`, `samsung_conversation_tile.dart`
- `pinned_conversation_tile.dart` — special display for pinned chats
- `pinned_tile_text_bubble.dart` — text preview bubble in pinned section
- `list_item.dart` — generic reusable row wrapper

**Footer** (`widgets/footer/`)
- `samsung_footer.dart` — bottom nav bar (Samsung skin only)

**Other**
- `widgets/pinned_chats_grid.dart`: paged pin grid sliver at the top of the list; every skin uses it, and lists below it pass `excludePinned: true`
- `widgets/server_v2_migration_banner.dart` — compact progress overlay inset from the top of the main chat list while v2 backfills run; shows the step, counts, and a horizontal progress bar without changing the list layout; shared by all skins and desktop layouts
- `conversation_list_fab.dart` — FAB to open `ChatCreator`
- `initial_widget_right.dart` — empty right-pane placeholder on tablet
- `dialogs/conversation_peek_view.dart` — hover message preview (desktop)

**Pin drag** (`widgets/pin_drag/`) — dragging chats onto, around and off the pins. State is per list:
`ConversationListController.pinDrag` (a `PinDragController`), passed down to every piece below, never looked up globally.
- `pin_drag_controller.dart` — `PinDragController`: drag state, derived values for narrow `Obx` scopes, pin order preview and commit
- `chat_drag_source.dart` — `ChatDragSource`: makes a pin or list row draggable; hold on touch, click and drag with a mouse
- `chat_draggables.dart` — `TouchChatDraggable` (hold then drag; touch, stylus) and `MouseChatDraggable` (click and drag; on a row only a mostly horizontal move starts it where a mouse drag scrolls the list). Chosen per pointer, not per platform
- `pin_drag_source.dart` — `PinDragSource`: wraps a list row in `ChatDragSource`, or shows the room made for an unpin
- `unpin_drop_target.dart` — `UnpinDropTarget`: the list below the grid; unpins a pin dropped on it
- `chat_drag_feedback.dart` — `ChatDragFeedback`: what follows the pointer, a pin or a list tile
- `drop_flight.dart` — `DropFlight`: a dropped chat flying into its slot
- `drop_slot.dart` — `DropSlot`: marks where a `DropFlight` lands
- `pin_grid_slot.dart` — `PinGridSlot`: one pin in the grid, and the drop target that previews a reorder on it
- `pin_placeholder.dart` — `PinPlaceholder`: the empty "Drag here to pin" pin shown while dragging with no pins
- `grow_in.dart` — `GrowIn`: opens from nothing to its child's height
- `dashed_circle.dart` — `DashedCirclePainter`: the empty pin's outline

## Skin Pattern
All three skins share `ConversationListController`. Branch via `ThemeSwitcher` — never put skin-conditional logic inside shared tile widgets.

## Service
Chat list state: `ChatsSvc` → `lib/services/ui/chat/chats_service.dart`

## Search Notes
- Prefer typed search mode (`SearchMode`) over string literals (`"local"`, `"network"`).
- Keep SQL/ObjectBox query-building and message/chat hydration in `search_query_helper.dart`, not inline in `search_view.dart`.
