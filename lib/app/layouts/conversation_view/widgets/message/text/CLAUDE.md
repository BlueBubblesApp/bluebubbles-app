# widgets/message/text/ — Text Bubble Renderer

## Files
| File | Purpose |
|------|---------|
| `text_bubble.dart` | Renders the text content for a single message part; handles plain text, rich text (attributed body), mentions, and edit-unsent styling |

## How Text is Rendered
`TextBubble` uses `buildMessageSpans()` immediately, then `buildEnrichedMessageSpans()` for detected entities.
Both share `message_run_spans.dart`: split part text at attributed-run and entity boundaries, combine bold,
italic, underline, and strikethrough, and read mentions directly from runs. URL detection remains a fallback.
Emoji fonts are applied per segment; inline Genmoji placeholders are substituted afterward.
Redacted content skips source runs and actions; subject-only rendering omits the body.

## Edit / Unsent States
- Edited messages show strikethrough on the original text part
- Unsent parts show "Unsent" label in muted style

## Related
- Attributed body helper: `lib/helpers/ui/message_run_spans.dart`
- Message part model: `lib/database/global/message_part.dart`
- Parent dispatcher: `../message_holder.dart` → `MessagePartContent`
