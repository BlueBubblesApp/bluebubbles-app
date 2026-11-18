# popup/ — Long-Press Context Menu

Handles the action sheet / context menu shown when the user long-presses (or right-clicks on desktop) a message bubble.

## Files

| File | Purpose |
|------|---------|
| `message_popup_holder.dart` | `GestureDetector` wrapper inside message bubbles; triggers popup presentation |
| `message_popup.dart` | Core popup layout/composition and action availability rules |
| `message_popup_action_context.dart` | Shared typed context passed to extracted action functions |
| `details_menu_action.dart` | Individual menu action row widget |
| `reaction_picker_clipper.dart` | `CustomClipper` for tapback picker shape |
| `actions/media_actions.dart` | Attachment/media actions (save/open/share/copy/redownload) |
| `actions/text_actions.dart` | Text/link actions (copy text, copy selection, open link) |
| `actions/navigation_actions.dart` | Navigation actions (reply/thread/DM/forward/new conversation) |
| `actions/message_actions.dart` | Message lifecycle actions (edit/unsend/delete/bookmark/remind/info/etc.) |
| `widgets/reaction_details.dart` | Reactions preview widget rendered at top of popup |
| `widgets/emoji_tapback_picker.dart` | The tapback row's `+`: an emoji picker, with a Stickers tab (`StickerLibraryView`) where sticker tapbacks are supported. Resolves to a `TapbackPick`; a sticker goes out through `OutgoingMsgHandler.queueStickerTapback`, and your own sticker tapback shows in the tapback row, where tapping it takes it back |

## MessagePopupActionContext Contract

`MessagePopupActionContext` carries the data/dependencies needed by reusable action handlers:
- UI context: `context`, `widthContext`, `popDetails`, `showSnack`
- Message scope: `messageState`, `message`, `part`, `chat`, `service`
- Controller scope: `cvController`
- Capability flags: `serverDetails`, `isEmbeddedMedia`
- Related entities: `dmChat`
- Action metadata: `action`

## How It Works

1. `MessagePopupHolder` triggers `showMessagePopup(...)` from a message bubble.
2. `MessagePopup` computes action availability and ordering in `_allActions`.
3. Each menu action callback builds a `MessagePopupActionContext` and dispatches into `actions/*.dart`.
4. Action functions own behavior; `message_popup.dart` owns visibility conditions and layout.

## Adding a New Popup Action

1. Add/confirm enum + icon entry in `details_menu_action.dart`.
2. Add a reusable function in the appropriate `actions/*.dart` file (or add a new category file if needed).
3. Wire the callback in `message_popup.dart` using `_buildActionContext(...)`.
4. Add action visibility condition in `_allActions` and ensure ordering via `SettingsSvc.settings.detailsMenuActions`.
5. Verify desktop and mobile behavior (availability + navigation/pop semantics).

## Desktop Behavior

On desktop, right-click opens this popup (instead of long-press). `MessagePopupHolder` handles gesture differences for desktop vs mobile.
