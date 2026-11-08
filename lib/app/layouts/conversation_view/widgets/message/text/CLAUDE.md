# widgets/message/text/ — Text Bubble Renderer

## Files
| File | Purpose |
|------|---------|
| `run_text_effects.dart` | Paints Big (5), Small (11), Shake (9), and Nod (8) from paragraph selection boxes without changing layout, semantics, or link hit regions |
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

## Inline Text Effects
`TextBubble` owns one animation controller for supported effect runs. Runs start in text order within each cycle;
cycles repeat while the bubble overlaps its scroll viewport. Scrolling offscreen, disabled tickers, reduced motion,
and redaction stop painting animated text. The controller is disposed with the bubble. These are approximations
of Apple's transforms; other effect IDs remain static and retained. Paragraphs with inline widget attachments
(Genmoji) stay static to avoid reparenting their composited layers during repeated paragraph painting.
Emoji glyphs still animate. Echo is a separate screen effect.

Timing reference: Tech Life Unity's native iPhone effect-picker footage
https://www.youtube.com/watch?v=7Om3ktMJcjc, 52–64 seconds. Text size/position traces repeat at about
49 frames / 24 fps (~2.04 seconds). The implementation uses a 2.05-second cycle, a size hold/return,
and a shorter motion burst followed by rest. Received-message timing on current iOS is not independently verified.
