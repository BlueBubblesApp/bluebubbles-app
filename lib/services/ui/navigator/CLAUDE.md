# services/ui/navigator/ — Navigation Service

## File
`navigator_service.dart` — `NavigatorService` (shorthand: `NavigationSvc`), plus the observers that track what is open:
`PaneObserver`, `SectionObserver` and the opaque-only `paneRouteObserver`.

## Responsibilities
The one place that decides which navigator a page goes into. Always use it instead of `Navigator.of(context)`
in feature code.

## Layout
- **Root navigator** (`NavigationSvc.key`): `Home`, plus Settings and Find My when open. They are *sections*: full-window
  pages pushed by `openSettings` / `openFindMy`, named after `AppSection`, tracked by `sectionObserver` into `openSection`.
- **Chat list split**: nested navigator 1 (left: the list, search, archived) and 2 (right: chats and pages opened from them).
- **Settings split**: nested navigator 3 (right pane of Settings).
- The phone layout keeps the same navigators and stacks the right pane over the left while it has a page
  (`chatPaneOpen` / `settingsPaneOpen`, driven by `PaneObserver`). Folding or resizing keeps what's open.

## Key Methods
```dart
NavigationSvc.push(context, widget)                       // into Settings' right pane while Settings is on top, the chat pane otherwise
NavigationSvc.pushLeft(context, widget)                   // the chat list's left pane (the chat pane on a phone with a chat open)
NavigationSvc.pushAndRemoveUntil(context, widget, pred)   // the chat pane; closes sections first; animate: false skips the transition in
NavigationSvc.openSettings(initialPage: page)             // Settings section, or switch page if it's already open
NavigationSvc.openFindMy()                                // Find My section
NavigationSvc.closeSections()                             // remove Settings and Find My, revealing the chat list and chat
NavigationSvc.pushSettings(context, widget)               // a page inside Settings (same as push while Settings is open)
NavigationSvc.pushAndRemoveSettingsUntil(context, w, p)   // swap Settings' right pane page (split view) or push (phone)
NavigationSvc.back()                                      // what Esc and system back do; false when there was nothing to go back from
NavigationSvc.pop(context)                                // pop the route the context is in
NavigationSvc.onChatList                                  // nothing open over the chat list (GetX's Get.rawRoute can't see the panes)
```

## Why Not Navigator.of(context)
- The nearest navigator is often the wrong one: a page opened from the chat list belongs in the chat pane, and one
  opened while Settings is on top belongs in Settings' pane
- Service-layer code (notifications, intents) navigates without a widget context
- Closing Settings and Find My, closing the active chat and the phone layout's stacking stay in one place

## Covered chats
A chat stays mounted under Settings, Find My, details or fullscreen media. `ConversationView` sets
`ChatState.isCovered` through `ChatsSvc.setChatCovered` (which marks the chat read when it's uncovered) from
`openSection` and from opaque pushes over it in the chat pane, and `isChatActive` is false while covered. Code that
acts on "the chat the user is looking at" should check `isChatActive` or `isCovered`, not just `ChatsSvc.activeChat`.

## Related
- Route definitions: `lib/main.dart` (Esc is registered above the root navigator there)
- Split view widget: `lib/app/wrappers/tablet_mode_wrapper.dart`
