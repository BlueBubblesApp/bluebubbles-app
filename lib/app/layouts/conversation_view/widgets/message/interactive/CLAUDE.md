# interactive/ — Rich / Interactive Message Renderers

Handles messages with Apple payload data: URL previews, Apple Pay, Game Pigeon invitations, embedded media (maps, music, iBooks), and generic interactive types.

## Files

| File | Purpose |
|------|---------|
| `interactive_holder.dart` | **Entry point** — routes on `message.payloadData` type |
| `url_preview.dart` | Link previews — owns `UrlPreviewController`, dispatches to a skin |
| `url_preview_controller.dart` | All fetch/cache/policy wiring for the preview card |
| `cupertino_url_preview.dart` | iOS skin (20px corners, blur-fill image) |
| `expressive_url_preview.dart` | Material/Samsung skin, M3 Expressive |
| `apple_pay.dart` | Apple Pay request / confirmation UI |
| `game_pigeon.dart` | Game Pigeon game invitation card |
| `embedded_media.dart` | Maps, Apple Music, iBooks, and other embedded content types |
| `photo_slideshow.dart` | Photos app / iCloud shared album card. Falls back to a preview image fetched from the share URL (via `MetadataHelper.fetchForMessage(urlOverride:)`/`resolveCachedImage`, disk-cached) when the message has no attachment. Uses `MetadataCacheSlot.photoSlideshow`. |
| `supported_interactive.dart` | Generic fallback for known-but-unsupported interactive types |
| `unsupported_interactive.dart` | Fallback for completely unknown interactive types |

## Routing Logic

`InteractiveHolder` inspects `message.payloadData`:

```
PayloadType.url          → UrlPreview (or UrlPreview.legacy for old servers)
PayloadType.applePay     → ApplePay
PayloadType.gamePigeon   → GamePigeon
PayloadType.embeddedMedia → EmbeddedMedia (maps, music, etc.)
(known type)             → SupportedInteractive
(unknown)                → UnsupportedInteractive
```

Called from `MessagePartContent` when `message.hasApplePayloadData || message.isInteractive`.

## Key Patterns

- All interactive widgets use `AutomaticKeepAliveClientMixin` to preserve state during scroll (prevents re-fetching URL metadata on every scroll).
- Tap handling is wrapped in `Obx()` to observe selection mode — in selection mode, taps select the message rather than triggering the interactive action.
- URL previews use `MetadataHelper.fetchForMessage()`, which returns a `MetadataFetchResult` and
  never throws — see `lib/helpers/network/metadata/CLAUDE.md`.
- Cached preview state is read/written through `MessageMetadataStore`, never by touching
  `message.metadata` keys directly.
- Transient fetch failures (`!result.shouldMarkAttempted`) must not be recorded as attempts, or
  the message loses its preview permanently.
- **Never point an `Image.network` at a payload/metadata image or icon URL off web.** It is an
  ungated outbound request to a third-party host issued from `build`, and it bypasses
  `shouldAutoFetch`, the disk cache and `UrlSafetyGuard`. Both skins render images only from
  `previewImagePath`/`iconImagePath`, falling back to the network solely via the controller's
  `webImageUrl`/`webIconUrl` (both null off web). Every image needs an `errorBuilder`, and every
  `DecorationImage` an `onError` — a dead host would otherwise escape as an uncaught rendering
  error.
- `UrlPreview` fixes the card's width to the constraints it is handed (except in a reply bubble),
  so the card does not resize as the title, the tap-to-load affordance, or the image arrive.
  Height is the only thing that changes, and it animates. Don't reintroduce shrink-wrapping.

## URL Preview Shapes

`UrlPreviewController.layout` picks one of three shapes from what actually resolved. Both skins
implement all three, at the same width, so moving between them only changes height:

| `UrlPreviewLayout` | When | Renders |
|---|---|---|
| `hero` | a preview image resolved (or a plugin payload carries artwork) | image, then the text block |
| `compact` | no image, but the page supplied a title, a summary, **or just a favicon** | the text block alone, tighter padding — **no summary**, which is what makes it shorter |
| `bare` | nothing resolved at all | a single line showing the link |

**The text block** is title first, then a source row of favicon + domain beneath it — the iOS
skin's order, and Google Messages'. Both Expressive shapes share one `_buildTextBlock`, so they
cannot drift. The Expressive skin previously led with the site line and hung a 40px favicon off
the left of the whole block; that read as a list tile rather than a link card. The favicon is now
inline with the domain, sized to that line's text.

When the title *is* the host — what `titleFor` falls back to when the page supplied no title —
the title is dropped and only the source row renders, since otherwise the domain prints twice,
once in bold. That is the shape an icon-only card takes.

A resolved favicon alone is enough for `compact`. `compact` is the only shape that draws the icon,
so keying purely on title/summary meant a page publishing an icon and nothing else fell to `bare`
and the downloaded icon was silently discarded — the card showed a generic link glyph instead of
the site's own mark. Such a card renders the icon beside the host, since `titleFor` falls back to
the host. Key on `hasIcon` (backed by `iconImagePath`, set only after a successful download), never
on `metadata.iconUrl` — `IconParser` guesses `/favicon.ico` for every page, so that field is almost
always non-null whether or not an icon actually exists.

**Payload image, fetched words.** Apple's payload often arrives as artwork and nothing else — a
plugin-payload attachment, or an `imageMetadata` with no `title`. That used to short-circuit the
whole load, leaving a hero image headed by the bare host. It now takes the image from the payload
and still runs the normal metadata fetch for the title and summary
(`_payloadNeedsMetadata` → `_fetchMissingMetadata(keepPayloadImage: true)`). `keepPayloadImage`
suppresses only the `og:image` download — the payload's picture is already on screen, so replacing
it costs a request and a second file on disk for no visible gain — and the persisted image hash
survives because `MessageMetadataStore.write` only writes hashes it is handed. The fetch is gated,
TTL'd and cached exactly like any other. A payload that supplied a title but no description does
**not** trigger this: it already reads fine, and fetching for a description alone would put a
request behind nearly every preview in the app.

**When the payload artwork is a dead end.** `keepPayloadImage` must never be hardcoded `true` for
the plugin-payload branch. It suppresses the `og:image` download, so a payload whose attachment
never produces a file left the card imageless with no way back — and because that branch returns
early, "Refresh Preview" on such a message did *nothing at all*. `keepPayloadImage` is now
`!artworkIsDeadEnd`, where a dead end is `force && !hasPayloadArtwork`.

The `force` half is load-bearing. `AttachmentsSvc.getContent` returns a download controller and
calls `onComplete` later, so on the first build of a new message the artwork is almost never on
hand yet. Treating that as "no artwork" would fetch the page's `og:image` for nearly every payload
message, and `showsAppleImage` makes the downloaded image win over the artwork that lands a moment
later — inverting the precedence this whole path exists to preserve. So an automatic load trusts
the artwork is coming; only a deliberate load (refresh, tap-to-load), where the attachment has
already had its chance, is allowed to conclude it is not.

A favicon never promotes a card to `hero` — it is a 40px mark beside the title, not a hero image.
The tap-to-load affordance renders in all three, or a gated link could never be loaded. In `hero`
and `compact` it renders **above** the title/site line, not below — the affordance is the card's
headline in this state, since nothing has actually loaded yet; only payload text (title/site line,
when Apple's payload carried one) can appear above it. `bare` keeps the button below its one line,
since there is no title/site line to lead with.

**"Refresh Preview" is consent.** The `previewRefreshKey` reload runs with `force`/`manual` set,
exactly like tap-to-load — the user picked the action out of a menu. Without it, refreshing a
preview whose sender `shouldAutoFetch` gates just replaces the card with the tap-to-load prompt,
so the refresh appears to undo itself. Every other protection still applies. This holds for
`PhotoSlideshow` too, which listens to the same key.

**Refresh rolls back.** It is destructive before it is productive: `refreshPreview` clears the row,
the controller blanks its own state, and only then is the network involved — so any failure after
that point (host down, bot block, connection dropped) used to leave a message that had a working
preview a second ago permanently blank. `_CardSnapshot` is captured before the clear and restored
when the reload produces nothing, and it re-persists the metadata too, since the row is already
gone by the time the worker runs. The image hashes are recovered from the cached file basenames —
`FilesystemSvc.urlPreviewImagePath` is `join(dir, hash)` and those files are never deleted.

"Produced nothing" is measured with the same `_CardSnapshot.hasContent` on both sides, and counts
only what a *load* yields. Payload title/summary arrive with the message and are there either way,
so counting them would make a refresh that lost everything look like a success. A partial success
is left alone — the fresher answer wins, and stitching the old image onto new words would render a
card that never existed.

Both the preview image and the favicon animate in on a **fresh download only** —
`imageAnimation` / `iconAnimation` sit at their end value by default and are only rewound by
`_setPreviewImage`/`_setIconImage` when `fromDisk` is false, so scrolling past a cached card is
instant rather than replaying every animation.

The plugin payload's artwork is a **third** image path and needs its own flag. It is an attachment,
not a URL, so it never touches `previewImagePath` and is rendered by its own branch in both skins —
which is why it appeared with no animation at all until `appleImageFromDisk` existed.
`AttachmentsSvc.getContent` draws exactly the right line for free: it returns a `PlatformFile`
synchronously when the file is already downloaded, and only calls `onComplete` when it actually had
to fetch it. So the flag starts true (no animation) and is cleared in that callback.

The card has two independent progress signals, both rendered by every shape:
`manualLoadRunning` (tap-to-load, shown inside the affordance itself) and `refreshRunning`
(the popup menu's "Refresh Preview", a trailing spinner). Refresh clears the card back to nothing
before re-fetching, so without the spinner it reads as the preview having vanished.

## Skin Handling

`widgets/message/` uses **inline property branching**, not `ThemeSwitcher` and not per-skin files —
`iOS ? 30 : 35`, `skin.value == Skins.iOS ? 10 : 12.5`. `url_preview` is the one exception, because
its Material variant is M3 Expressive and genuinely differs in structure (no blur-fill, different
image crop, `M3ETonalButton` affordance), which ternaries express badly.

It still avoids `ThemeSwitcher`: that takes already-constructed widgets for every skin, so it would
allocate both variants per message per build. A plain `iOS ? Cupertino... : Expressive...` in
`build()` constructs only the one used. `ThemeSwitcher`'s `Obx` is redundant here anyway — changing
the app skin runs `ChatsSvc.setAllInactive()` first, tearing down open conversation views so they
rebuild against the new skin.

**Presentation only in the skin files.** Anything touching the network, the disk cache, the sender
policy or the retry TTL belongs on `UrlPreviewController`, including derived values like the site
line — that one is security-relevant and must never diverge between skins.

The site line is the host, run through `SiteDisplayNames` so a mapped domain renders as its
friendly name (`chat.whatsapp.com` → WhatsApp). The map is a `const` in code, not a setting, and
is resolved at display time, so adding an entry re-labels cached cards with no refetch. See
`helpers/network/metadata/CLAUDE.md` → **Site Names**.

## Adding a New Interactive Type

1. Add the new `PayloadType` value to the enum in `lib/database/io/message.dart`.
2. Create `my_type.dart` in this directory.
3. Add a branch in `interactive_holder.dart`.
