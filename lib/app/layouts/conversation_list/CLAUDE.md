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
- `widgets/server_v2_migration_banner.dart` — compact progress overlay inset from the top of the main chat list while v2 backfills run; shows the step, counts, and a horizontal progress bar without changing the list layout; shared by all skins and desktop layouts
- `conversation_list_fab.dart` — FAB to open `ChatCreator`
- `initial_widget_right.dart` — empty right-pane placeholder on tablet
- `dialogs/conversation_peek_view.dart` — hover message preview (desktop)

## Skin Pattern
All three skins share `ConversationListController`. Branch via `ThemeSwitcher` — never put skin-conditional logic inside shared tile widgets.

## Service
Chat list state: `ChatsSvc` → `lib/services/ui/chat/chats_service.dart`

## Search Notes
- Prefer typed search mode (`SearchMode`) over string literals (`"local"`, `"network"`).
- Keep SQL/ObjectBox query-building and message/chat hydration in `search_query_helper.dart`, not inline in `search_view.dart`.
