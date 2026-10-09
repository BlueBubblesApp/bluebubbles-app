# services/ui/cache/ — Cache Service

Registry of every in-process cache the app can shrink or drop, and the policies that decide what
happens to each one at each purge level. Exists because Android's low memory killer evicts the
largest cached process first, and most of what this app holds while backgrounded is rebuildable.

## Files
| File | Contents |
|------|----------|
| `clearable_cache.dart` | `ClearableCache` interface, `CachePurgeLevel`, `CachePurgeAction`, `CachePurgeReport` |
| `cache_service.dart` | `CacheService` (`CacheSvc`) — registry, granular ops, policy-driven purges, in-flight serialisation |
| `app_caches.dart` | The built-in caches and `defaultAppCaches()`, registered in `StartupTasks.initStartupServices()` |

## Built-in caches
| id | Holds | Trim by size |
|----|-------|--------------|
| `images` | Flutter's decoded-image cache (`PaintingBinding.instance.imageCache`) | yes |
| `videoPlayers` | media_kit controllers cached on open `ConversationViewController`s | no |
| `adaptiveThemes` | `ThemesService` per-image Material You theme sets | no |
| `engine` | GPU textures, Skia/Impeller resource cache, VM heap pages — via the `trim-memory` method channel (Android only) | no |

## Levels (default policies)
- `off` (null) — nothing runs automatically
- `light` — trim `images` to 25% of current, purge `engine`, leave the rest. **Default on background.**
- `moderate` — clear everything except `videoPlayers` (the only cache with a visible rebuild cost). **Default on memory pressure.**
- `aggressive` — clear everything.

Defaults start at the minor end on purpose: raise them only as device testing shows what each step buys and what
it costs on resume. Caches a policy does not name get `defaultActions[level]`, so a newly registered cache is
covered immediately.

## Settings (persisted, `lib/database/global/settings.dart`)
| Key | Values | Default |
|-----|--------|---------|
| `cachePurgeBackgroundLevel` | `off` / `light` / `moderate` / `aggressive` | `light` |
| `cachePurgeMemoryPressureLevel` | same | `moderate` |
| `cachePurgeExcludedCaches` | comma-separated cache ids skipped by automatic purges | empty |

`CacheSvc.loadFromSettings()` (extension in `app_caches.dart`) applies them at startup and after every change.
The Developer Tools → Cache Tuning page (`settings/pages/misc/cache_tuning_panel.dart`) edits them, runs any level
or single cache by hand, and shows live process memory (`memory-stats` channel) next to the last purge report.

## Granular use
```dart
await CacheSvc.clear('images');
await CacheSvc.trim('images', 8 * 1024 * 1024);
await CacheSvc.clearMany(['images', 'videoPlayers']);
await CacheSvc.apply({'images': const CachePurgeAction.trimToFraction(0.5)});
await CacheSvc.purge(CachePurgeLevel.aggressive, reason: 'user request');
CacheSvc.snapshot(); // sizes and entry counts for diagnostics
```
Every purge logs a before/after report under tag `CacheService`; the Android handler logs process PSS
before and after the engine purge to `native.log`.

## Adding a cache
1. Extend `ClearableCache`; implement `id`, `description`, `clear()`. Report `currentSizeBytes` / `entryCount`
   whenever cheaply possible — the report is how a change gets verified on a device.
2. Override `supportsTrim` + `trimTo()` only when a size-bounded trim is genuinely possible.
3. Add it to `defaultAppCaches()` (or `CacheSvc.register()` from the owning service's init) and, if the default
   action per level is wrong for it, an entry in `CacheService.policies`.
4. If disposing its contents can strand a mounted widget, emit an event (see `kVideoPlayersEvictedEvent`) and
   handle it in the widget.

## Memory-pressure echo
`EngineResourceCache.clear()` makes the engine fire Flutter's own `memoryPressure` callback, which lands in
`LifecycleService.didHaveMemoryPressure`. `markEnginePurgeRequested()` flags the next such callback (10 s window)
so it is not mistaken for a genuine OS warning and turned into a second, aggressive purge.
