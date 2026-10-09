import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/cache/cache_service.dart';
import 'package:bluebubbles/services/ui/cache/clearable_cache.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

/// Event emitted (with the chat GUID as data) after [VideoPlayerCache] disposes
/// a conversation's inline video players, so widgets holding one can fall back
/// to their thumbnail instead of driving a disposed controller.
const String kVideoPlayersEvictedEvent = 'video-players-evicted';

/// Keys in `Settings` that drive the automatic purges. The developer tools
/// page writes them; [CacheServiceSettings.loadFromSettings] reads them.
const String kCachePurgeBackgroundLevelKey = 'cachePurgeBackgroundLevel';
const String kCachePurgeMemoryPressureLevelKey = 'cachePurgeMemoryPressureLevel';
const String kCachePurgeExcludedCachesKey = 'cachePurgeExcludedCaches';

extension CacheServiceSettings on CacheService {
  /// Applies the persisted purge levels and exclusions. Called once at startup
  /// and again whenever the developer tools page changes one of them.
  void loadFromSettings() {
    if (!GetIt.I.isRegistered<SettingsService>()) return;
    final settings = SettingsSvc.settings;
    backgroundLevel = cachePurgeLevelFromName(settings.cachePurgeBackgroundLevel.value);
    memoryPressureLevel = cachePurgeLevelFromName(settings.cachePurgeMemoryPressureLevel.value);
    excludedIds
      ..clear()
      ..addAll(parseExcludedCacheIds(settings.cachePurgeExcludedCaches.value));
    Logger.debug(
      'Loaded purge settings: background=${cachePurgeLevelName(backgroundLevel)}, '
      'memoryPressure=${cachePurgeLevelName(memoryPressureLevel)}, excluded=${excludedIds.join(',')}',
      tag: 'CacheService',
    );
  }
}

/// The exclusion setting is a comma-separated list of cache ids.
Set<String> parseExcludedCacheIds(String raw) =>
    raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

/// The caches the main app registers at startup, in the order they are purged.
///
/// Order matters a little: Dart-side caches go first so their memory is
/// already unreferenced by the time the engine purge triggers a garbage
/// collection.
List<ClearableCache> defaultAppCaches() => [
      FlutterImageCache(),
      VideoPlayerCache(),
      AdaptiveThemeCache(),
      EngineResourceCache(),
    ];

/// Flutter's decoded-image cache: every attachment thumbnail, avatar, link
/// preview and chat icon that has been painted recently.
///
/// Defaults to 100 MB and 1000 images and is the single largest rebuildable
/// block of Dart-side memory in this app. Everything in it reloads from disk.
class FlutterImageCache extends ClearableCache {
  ImageCache get _cache => PaintingBinding.instance.imageCache;

  @override
  String get id => 'images';

  @override
  String get description => 'Decoded images (attachments, avatars, previews)';

  @override
  int? get currentSizeBytes => _cache.currentSizeBytes;

  @override
  int? get entryCount => _cache.currentSize;

  @override
  bool get supportsTrim => true;

  @override
  Future<void> clear() async {
    _cache.clear();
    // Live images are still referenced by mounted widgets, so this frees
    // nothing by itself; it stops the cache re-adopting them on the next frame.
    _cache.clearLiveImages();
  }

  /// Shrinks by briefly lowering the byte ceiling. The setter evicts least
  /// recently used entries synchronously until the cache fits, so restoring
  /// the ceiling straight after leaves the cache small but fully usable.
  @override
  Future<void> trimTo(int maxBytes) async {
    if (_cache.currentSizeBytes <= maxBytes) return;
    final original = _cache.maximumSizeBytes;
    _cache.maximumSizeBytes = math.max(0, maxBytes);
    _cache.maximumSizeBytes = original;
  }
}

/// Inline video players held by open conversations.
///
/// Each one keeps a media_kit decoder, its buffers and a GPU surface alive even
/// while paused, which is why this is the largest per-item cache the app has.
/// Disposing them only costs the bubble a fall back to its thumbnail; the next
/// tap rebuilds the player from the file on disk.
class VideoPlayerCache extends ClearableCache {
  @override
  String get id => 'videoPlayers';

  @override
  String get description => 'Inline video players in open conversations';

  @override
  int? get entryCount => _controllers().fold<int>(0, (sum, c) => sum + c.videoPlayers.length);

  @override
  Future<void> clear() async {
    for (final controller in _controllers()) {
      final released = controller.disposeVideoPlayers();
      if (released == 0) continue;
      Logger.debug('Released $released video player(s) for chat ${controller.chat.guid}', tag: 'CacheService');
      if (GetIt.I.isRegistered<EventDispatcher>()) {
        EventDispatcherSvc.emit(kVideoPlayersEvictedEvent, controller.chat.guid);
      }
    }
  }

  /// Every live conversation controller. On mobile that is at most the open
  /// chat; on desktop controllers are permanent, so this walks the chat list.
  Iterable<ConversationViewController> _controllers() {
    if (!GetIt.I.isRegistered<ChatsService>()) return const [];
    return ChatsSvc.chatStates.keys
        .where((guid) => Get.isRegistered<ConversationViewController>(tag: guid))
        .map((guid) => Get.find<ConversationViewController>(tag: guid));
  }
}

/// Material You theme sets generated from chat background images, keyed by
/// image path. Small per entry, but each holds eighteen full `ThemeData`
/// objects and the set only grows while the app runs.
class AdaptiveThemeCache extends ClearableCache {
  @override
  String get id => 'adaptiveThemes';

  @override
  String get description => 'Themes generated from chat background images';

  @override
  int? get entryCount => ThemesService.adaptiveThemeCacheSize;

  @override
  Future<void> clear() async => ThemesService.clearAllAdaptiveThemeCaches();
}

/// The Flutter engine's own caches: GPU textures, the Skia/Impeller resource
/// cache and unused Dart VM heap pages.
///
/// These cannot be released from Dart. On Android the method channel asks the
/// activity to do what `FlutterActivityAndFragmentDelegate` does on an OS trim
/// callback, which makes the purge explicit and logged instead of dependent on
/// whether the OS happened to send one. Flutter echoes that purge back as a
/// memory-pressure callback, which [CacheService.onMemoryPressure] recognises
/// via [CacheService.markEnginePurgeRequested] and ignores.
class EngineResourceCache extends ClearableCache {
  @override
  String get id => 'engine';

  @override
  String get description => 'Engine GPU and VM caches (Android)';

  @override
  Future<void> clear() async {
    if (kIsWeb || kIsDesktop || !Platform.isAndroid) return;
    if (!GetIt.I.isRegistered<MethodChannelService>() || !GetIt.I.isReadySync<MethodChannelService>()) return;
    if (GetIt.I.isRegistered<CacheService>()) CacheSvc.markEnginePurgeRequested();
    await MethodChannelSvc.actions.trimMemory();
  }
}
