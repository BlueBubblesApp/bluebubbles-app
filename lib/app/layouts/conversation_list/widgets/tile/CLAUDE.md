# widgets/tile/ — Conversation List Tile

Individual chat row rendered in the conversation list. Each tile displays the chat avatar, name, last message preview, timestamp, and unread badge.

## Files

| File | Purpose |
|------|---------|
| `conversation_tile.dart` | Base widget + `ConversationTileController`; dispatches to skin via `ThemeSwitcher` |
| `material_conversation_tile.dart` | Material Design skin |
| `cupertino_conversation_tile.dart` | iOS Cupertino skin |
| `samsung_conversation_tile.dart` | Samsung One UI skin |
| `pinned_conversation_tile.dart` | Horizontal layout for the pinned chats section |
| `pinned_tile_text_bubble.dart` | Text preview bubble rendered inside the pinned section |
| `list_item.dart` | Generic row wrapper; adds `Dismissible` swipe actions (Material only) |
| `trailing_state_mixin.dart` | Mixin sharing trailing-widget (timestamp/badge) reactive state across tile skins |

## Controller: `ConversationTileController`

Tag: `chat.guid`. Set `permanent: kIsDesktop || kIsWeb`.

Key reactive properties:
- `shouldHighlight` — true when this chat is actively open on desktop (split view)
- `shouldPartialHighlight` — tablet hover state

Sub-widgets `ChatTitle`, `ChatSubtitle`, and `ChatLeading` manage their own state independently for reusability — they are not built inline in the tile.

## Skin Pattern

`ConversationTile` uses `ThemeSwitcher` to dispatch to the correct skin:
```dart
ThemeSwitcher(
  iOSSkin:      CupertinoConversationTile(parentController: controller),
  materialSkin: MaterialConversationTile(parentController: controller),
  samsungSkin:  SamsungConversationTile(parentController: controller),
)
```

All three skins receive the same `ConversationTileController` and read its `Rx*` properties. **Never add skin-conditional logic inside `ConversationTile` itself** — branch inside each skin widget.

## Pinned Tiles

Pinned chats are rendered by `PinnedChatsGrid` (`../pinned_chats_grid.dart`) at the top of the list in every skin, in `pinIndex` order (a pinned chat always has one). Dragging (hold then drag on touch, click and drag with a mouse, chosen per pointer so a desktop touchscreen holds too; a mostly vertical mouse drag on a list row still scrolls where a mouse drag scrolls) reorders pins, pins a list chat dropped on the grid (`PinDragSource`), and unpins a pin dropped on the list (`UnpinDropTarget`); the drag pieces live in `../pin_drag/` and share the list's `PinDragController` (`ConversationListController.pinDrag`), which a pinned tile gets as `pinDrag`. Because the drag claims the hold, a hold released in place peeks on iOS and selects on Material/Samsung. There is no separate pin order screen. `PinnedConversationTile` uses a column layout (avatar + name stacked vertically) rather than the row layout of standard tiles.

## Swipe Actions

`ListItem` wraps `ConversationTile` in a `Dismissible` for swipe-to-archive / swipe-to-pin on Material skin. iOS swipe actions are handled by the Cupertino skin tile directly.

## Data Source

Chat data flows from `ChatsSvc` → `ChatState`. The tile observes `ChatState` fields via `Obx()` for the last message preview, unread count, and highlight state.
