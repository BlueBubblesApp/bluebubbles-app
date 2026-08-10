# settings/pages/storage/ — Storage Analyzer

Measures on-disk storage usage (by media type, filterable by chat and age) and lets the user
reclaim it. See `docs/feature-planning/storage-analyzer/STORAGE_ANALYZER_PLAN.md` for the full design.

## Global Segments
Most segments live under `attachments/<guid>/` and can be narrowed by chat and age.
`StorageSegmentType.orphaned` and `StorageSegmentType.urlPreviews` cannot — orphan folders map to no
DB row, and link preview images are content-addressed and shared by every message linking the same
page. Both are marked `isGlobal`, skipped entirely on a filtered scan, and reported via
`StorageAnalysisResult.globalScanValid` so the results view can explain their absence.

Link previews are never evicted automatically; clearing them here is the only way they go. A cleared
preview reloads on demand the next time its message is shown, subject to the same
`LinkPreviewPolicy` sender gate as any other fetch — see `lib/helpers/network/metadata/CLAUDE.md`.

## Files

| File | Purpose |
|------|---------|
| `storage_analyzer_panel.dart` | Entry point — owns `StorageAnalyzerController`'s lifecycle, routes to skin |
| `storage_analyzer_controller.dart` | `GetxController` — filter state, dispatches analysis runs, applies `runId`-filtered progress events |
| `storage_analyzer_helpers.dart` | `StorageAnalyzerHelpersMixin` — segment label/icon/color config, binary byte formatter |
| `cupertino_storage_analyzer_panel.dart` | iOS skin |
| `material_storage_analyzer_panel.dart` | Material M3 Expressive skin — built on `lib/app/components/m3e/` |
| `samsung_storage_analyzer_panel.dart` | Samsung M3 Expressive skin — same structure as Material |

## Widgets (`widgets/`)
- `storage_filter_bar.dart` — chat picker (`ChatSelectorView`) + age filter (`showBBListSelector`)
- `storage_analyze_prompt.dart` — iOS pre-analysis empty state
- `storage_progress_section.dart` — iOS determinate progress bar + stage label + live byte total
- `storage_results_section.dart` — iOS headline `StatTile`s, `DonutChart`, per-segment rows
- `storage_segment_row.dart` — iOS segment row: `SettingsLeadingIcon`, inline progress bar, size,
  file count, select toggle
- `storage_expressive_analyze_prompt.dart` — Material/Samsung empty state, `M3ETonalButton`
- `storage_expressive_progress_section.dart` — Material/Samsung progress UI, M3E type scale
- `storage_expressive_results_section.dart` — Material/Samsung results: `M3EStatTile`s (tonal
  container KPI tiles), `DonutChart`, `M3ESection`-grouped segment rows (internal `_SegmentTile`
  composes `M3EListTile` + a progress bar, since `M3EListTile` has no built-in progress slot)
- `storage_free_up_fab.dart` — `StorageFreeUpFab`: the floating "Free up N" action, shared by all
  three skins via `SettingsScaffold(fab: ...)`. Always mounted; pops in/out with `AnimatedScale` +
  `AnimatedOpacity` (450ms, `easeOutBack` on entry) as `selectedSegments` goes non-empty/empty —
  never swapped for `null`, so the animation (not a widget swap) drives visibility.
- `storage_cleanup_sheet.dart` — `showStorageCleanupSheet()`: yes/no confirm (`showAreYouSure`) for the
  currently-selected segments, shared by all three skins; also owns the post-delete summary dialog
  (`_showDeleteSummary`, via `showBBDialog`) showing bytes freed / files removed / items that will
  re-download.

## No Manual Refresh
There is no pull-to-refresh and no refresh button on any skin (Cupertino's `CupertinoSliverRefreshControl`
and the Material/Samsung toolbar refresh icon were both removed). The page re-analyzes only on: the
initial "Analyze" tap from the empty state, a filter change (`StorageAnalyzerController`'s `everAll`
listener on `selectedChat`/`ageFilter`, deferred one microtask to avoid a GetX reentrancy warning —
see the comment at its call site), or automatically after a delete completes, purely to verify the
deletion actually landed.

## Deletion Flow
`StorageAnalyzerController.selectedSegments`/`toggleSegment`/`selectedBytes` track the selection.
`StorageFreeUpFab` calls `showStorageCleanupSheet()` → `StorageInterface.deleteAttachments()` →
fires `controller.analyze()` in the background (`unawaited`) → shows the delete summary dialog.
Deletion always re-derives the attachment index from the DB rather than trusting the last Analyze
snapshot — see `StorageActions.deleteAttachments` in `storage_actions.dart`.

## Backend
`lib/models/storage_analysis.dart` (DTOs, incl. `StorageDeleteResult`) →
`lib/services/backend/interfaces/storage_interface.dart` →
`lib/services/backend/actions/storage_actions.dart` (runs inside `GlobalIsolate`). Progress is pushed
via `IsolateEvent.storageAnalysisProgress`, filtered by `runId` in the controller.

`StorageInterface.deleteAttachments()` does the isolate round-trip, then on the main thread: clears
`AttachmentsSvc`'s video thumbnail cache, clears any `AttachmentDownloader` controller for each reset
GUID, clears Flutter's `imageCache`, and emits a global `'storage-attachments-purged'` event (payload
`{'guids': List<String>}`) — `MessagesView` listens for this alongside its per-chat
`'refresh-messagebloc'` event since a purge can span multiple chats.
