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

**Pinned** (`widgets/pinned/`)
- `material_pinned_chats_section.dart` — Material skin's pinned chats: a paged grid of large avatars
  masked with M3 Expressive shapes, above the list. Behind the `enhancedPinnedTiles` setting and
  Material-only (Samsung's taller header leaves no room). Its `isEnabled` getter is also what tells
  `material_conversation_list.dart` to drop pinned chats from the main list — read both from the
  same place or pins render twice.

**Footer** (`widgets/footer/`)
- `samsung_footer.dart` — bottom nav bar (Samsung skin only)

**Other**
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
