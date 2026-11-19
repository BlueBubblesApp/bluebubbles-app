# lib/app/wrappers/ — Base Widget Classes & Scaffold Composition

## State Base Classes → `stateful_boilerplate.dart`

Pick the right base for every stateful widget:

| Class | Use when |
|-------|----------|
| `CustomStateful<T>` + `CustomState<T, R, S>` | Widget owns or shares a `StatefulController` |
| `StatelessWidget` | No state |

See `.claude/rules/frontend.md` for full controller tagging, `forceDelete`, and `Obx` rules.

## Scaffold & Layout
- `bb_scaffold.dart` — use instead of raw `Scaffold`; handles window transparency, system UI overlay, theme defaults
- `bb_annotated_region.dart` — base page wrapper for status/nav bar color styling
- `tablet_mode_wrapper.dart` — resizable split-view used by the chat list, Settings and Find My; configurable min/max pane ratios. Outside the split layout, passing `rightOpen` stacks the right pane over the left while it's true (the left pane is hidden, its animations paused and its focus excluded)
- `gradient_background_wrapper.dart` — animated gradient background driven by `ConversationViewController`
- `titlebar_wrapper.dart` — custom desktop window titlebar (bitsdojo_window / window_manager)

## Navigation & Skin Switching
- `theme_switcher.dart` — branches widget tree to iOS / Material / Samsung skin variant
- `custom_cupertino_page_transition.dart` (in `components/custom/`) — iOS push animation

## Utility Wrappers
- `fade_on_scroll.dart` — fades a header widget as user scrolls down
- `scrollbar_wrapper.dart` — styled scrollbar overlay
- `cupertino_icon_wrapper.dart` — normalizes Cupertino icon rendering
- `trackpad_bug_wrapper.dart` — macOS trackpad two-finger scroll fix

## When to Add Here
Add to `wrappers/` only for reusable, cross-screen composition. Screen-specific layout belongs in `layouts/`.
