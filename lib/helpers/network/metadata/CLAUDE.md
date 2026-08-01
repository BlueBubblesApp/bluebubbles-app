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
MetadataHelper.fetchForMessage()
  └─ UrlMetadataFetcher.fetch()            url_metadata_fetcher.dart
       ├─ MetadataUrls.parse                   scheme defaulting
       ├─ SiteParserRegistry.forUrl → prepare  canonicalise, strip trackers
       ├─ UrlSafetyGuard.checkResolved         reject private/loopback hosts
       ├─ MetadataHttpClient.fetch             capped, charset-aware, own Dio
       ├─ MetadataDocumentPipeline.run         OG → Twitter → JSON-LD → HTML
       │                                        → Microdata → BodyImage → Icon
       ├─ OEmbedResolver.resolve               only if a gap remains
       └─ SiteMetadataParser.refine            site-specific DOM knowledge
```

Concurrent calls for the same URL collapse onto one request (`MetadataMemoryCache`),
keyed by normalised URL — **not** by message GUID.

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

## Rules

- **Never** route third-party requests through `HttpSvc.dio` — see `../CLAUDE.md`.
- Parsers must not throw; the pipeline guards them, but returning `UrlMetadata.empty` is cheaper.
- Parsers return raw values. Cleanup (`MetadataText`) and URL resolution (`MetadataUrls`) happen
  once, in `UrlMetadata.normalized()`.
- Only `og:video:thumbnail` is acceptable as an image fallback — never `og:video`, which is a
  player URL or an .mp4.
- The preview image is validated (content type, size, dimensions ≥ 32px) before it reaches disk,
  which is what makes hostname blocklists for tracking pixels unnecessary.

## Settings

`SettingsSvc.settings.fetchUrlPreviews` gates all automatic fetching. Server-supplied previews
(Apple payload data) are unaffected. Explicit user actions (sharing a location) bypass the gate.
