# metadata/ — URL Preview Metadata Pipeline

Fetches and parses Open Graph / Twitter Card / JSON-LD / oEmbed metadata for link previews.
Replaces the former `metadata_fetch` package dependency.

Public entry point is `MetadataHelper` (`../metadata_helper.dart`), re-exported by
`helpers/helpers.dart`. Import the barrel `metadata/metadata.dart`, not individual files.

## Layout

| Directory | Responsibility |
|-----------|----------------|
| `models/` | `UrlMetadata`, `MetadataFetchResult`, `MetadataSource`, `MetadataFetchStatus` |
| `parsing/` | Document parsers + `MetadataDocumentPipeline` that merges them |
| `network/` | HTTP client, SSRF guard, charset decoding, oEmbed, image downloader |
| `sites/` | Per-site knowledge, registered in `SiteParserRegistry` |
| `cache/` | In-memory single-flight cache + `Message.metadata` persistence |
| `util/` | Text cleanup and URL resolution/normalisation |

## Flow

```
MetadataHelper.shouldAutoFetch()            policy + sender gate
MetadataHelper.fetchForMessage()
  └─ UrlMetadataFetcher.fetch()            url_metadata_fetcher.dart
       ├─ MetadataUrls.parse                   scheme defaulting
       ├─ SiteParserRegistry.forUrl → prepare  canonicalise, strip trackers
       ├─ MetadataHttpClient.fetch             own Dio; concurrency-limited
       │    └─ per hop: UrlSafetyGuard → request → follow Location manually
       ├─ HtmlStructureGuard.isSafe            reject pathological nesting
       ├─ MetadataDocumentPipeline.run         OG → Twitter → JSON-LD → HTML
       │                                        → Microdata → BodyImage → Icon
       ├─ OEmbedResolver.resolve               only if a gap remains
       └─ SiteMetadataParser.refine            site-specific DOM knowledge
```

Concurrent calls for the same URL collapse onto one request (`MetadataMemoryCache`),
keyed by normalised URL — **not** by message GUID. `PreviewImageDownloader` single-flights the
same way for image and icon downloads.

Two widgets asking for the same preview at once is the normal case, not an edge case:
`MessagePopup` renders a **second copy** of the bubble against the same `MessageState`, so both
copies' `previewRefreshKey` workers fire on "Refresh Preview" (it is dispatched before the popup
closes). Anything in this pipeline that hits the network must therefore be single-flighted, or
every long-press and every refresh does the work twice.

## Parser Precedence

`UrlMetadata.fillMissingFrom` never overwrites a field that is already set, so precedence is
expressed purely by the order parsers run in. To change precedence, reorder
`MetadataDocumentPipeline._primary`.

`MicrodataParser`, `BodyImageParser` and `IconParser` are conditional — they walk the DOM, so
the pipeline only runs them when the cheap strategies left the relevant gap.

## Adding a Site Parser

1. Create `sites/<site>_site_parser.dart` extending `SiteMetadataParser`.
2. Override only the hooks the site needs:
   - `prepare(url)` — canonicalise **before** the fetch (expand short links, drop site-specific
     tracking params). The user's original URL is preserved separately, so this never changes
     what tapping the preview opens.
   - `refine(base, context)` — fill gaps from the site's own DOM.
   - `fallback(url)` — facts derivable from the URL alone, applied when the fetch fails.
     Never invent a title or description here.
3. Register it in `SiteParserRegistry._parsers` (order is match order).

Currently registered: Apple Maps, YouTube, Amazon, Reddit.

## Persistence

Never read or write `message.metadata` keys directly — go through `MessageMetadataStore`.
`MetadataCacheSlot` owns the key names for each preview a message can carry
(`urlPreview`, `photoSlideshow`).

A completed attempt is stamped with a timestamp and retried after
`MessageMetadataStore.retryAfter` (24h). Retryable failures (timeout, 5xx, 429, socket error)
are deliberately **not** stamped, so they retry on the next build — see
`MetadataFetchResult.isRetryable`.

Legacy `metadata_fetch` keys (`image`, `url`, `previewImageFetched`) are still read and written
for backward and forward compatibility.

## Security Model

Link previews fetch attacker-chosen URLs and parse attacker-written markup, automatically,
for messages anyone can send. The protections and where they live:

| Concern | Where |
|---|---|
| Loopback / private / link-local targets | `UrlSafetyGuard`, called from `MetadataHttpClient` |
| Redirects into the LAN | `followRedirects: false` + per-hop guard in `MetadataHttpClient.fetch` |
| Permissive IPv4 literals (`127.1`, `0177.0.0.1`) | `UrlSafetyGuard.parseLooseIpv4` |
| Server credential leakage | dedicated `Dio`, never `HttpSvc.dio` |
| Oversized bodies | streaming caps in `MetadataHttpClient` |
| Stack overflow from nested markup | `HtmlStructureGuard`, before parsing |
| Connection/memory exhaustion | `FetchConcurrencyLimiter` |
| Tracking pixels, undecodable images | `PreviewImageDownloader` validation |
| Site-name spoofing | the card's site line comes from the URL, never `og:site_name` |
| Bidi text spoofing | `MetadataText.clean` |
| IP disclosure to unknown senders | `LinkPreviewPolicy` + `MetadataHelper.shouldAutoFetch` |

**`UrlSafetyGuard` is called in exactly one place** — inside `MetadataHttpClient.fetch`, per hop.
Do not add call sites elsewhere; do not re-enable dio's own redirect following. That combination
is what makes the guard cover the page fetch, discovered oEmbed endpoints, image downloads, and
every redirect between them.

**Known limitation:** the guard resolves a hostname and the socket layer resolves it again, so DNS
rebinding is not prevented. Dart's `HttpClient` does not expose enough control to connect to a
pinned address with the original Host header and SNI. `LinkPreviewPolicy.contactsOnly` (the
default) is the mitigation — it limits who can trigger an automatic fetch at all.

**A manual tap bypasses the policy and the retry TTL, and nothing else.** Every other protection
still applies to a user-initiated load.

## Rules

- **Never** route third-party requests through `HttpSvc.dio` — see `../CLAUDE.md`.
- Parsers must not throw; the pipeline guards them, but returning `UrlMetadata.empty` is cheaper.
- Parsers return raw values. Cleanup (`MetadataText`) and URL resolution (`MetadataUrls`) happen
  once, in `UrlMetadata.normalized()`.
- Only `og:video:thumbnail` is acceptable as an image fallback — never `og:video`, which is a
  player URL or an .mp4.
- The preview image is validated (content type, size, dimensions ≥ 32px) before it reaches disk,
  which is what makes hostname blocklists for tracking pixels unnecessary.
- Downsampling goes through `ImageInterface.generatePreview` — the same isolate action
  `AttachmentsSvc` uses for inline attachment previews. Don't write a second resize
  implementation here. It applies only to the hero image (`optimize: !isIcon`), and is skipped
  for GIF (re-encoding drops every frame but the first) and PNG (JPEG has no alpha). The cache
  hash stays a digest of the *downloaded* bytes, not of what lands on disk, so two messages
  linking the same og:image still share one cache entry.

## Settings

`SettingsSvc.settings.linkPreviewPolicy` (`LinkPreviewPolicy`) controls automatic fetching:

- `always` — fetch every link
- `contactsOnly` — **default** — fetch only for messages from a saved contact, or from the user
- `never` — tap to load, always

The gate is evaluated per *message sender* (`MetadataHelper.shouldAutoFetch`), not per chat, so a
stranger's links in a group are still gated.

It **fails closed**: a sender that cannot be confirmed as a contact counts as unknown — no handle,
contacts permission denied, a server without the contacts API, or a lookup error all gate the
preview. Denying contacts access therefore turns every link into tap-to-load rather than reverting
to fetching everything.

Apple's payload data supplies a title and summary with the message, and those always render — no
request involved. Its `imageMetadata.url` is *not* exempt: that image lives on a third-party host, so
downloading it is an outbound request and is gated like any other. Anything already on disk is served
without touching the network, which is why `MetadataHelper.resolveCachedImage` applies the gate only
on a cache miss.

A payload that carries **only** an image — no title and no summary, which is the common shape for a
plugin-payload attachment — still runs a normal, gated metadata fetch for the text. The payload
artwork wins; the fetch fills in title, summary and (when the payload had none) the icon. See
`UrlPreviewController._payloadNeedsMetadata`.
