import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Developer Tools page for the `CacheService`.
///
/// Exists so the purge levels can be tuned on a real device instead of guessed:
/// pick what runs automatically, run any level or any single cache by hand, and
/// read what each purge freed next to the process's live memory figures. The
/// usual loop is: set a level, background the app, come back, and see whether
/// what reloaded was worth what was freed.
class CacheTuningPanel extends StatefulWidget {
  const CacheTuningPanel({super.key});

  @override
  State<CacheTuningPanel> createState() => _CacheTuningPanelState();
}

class _CacheTuningPanelState extends State<CacheTuningPanel> with ThemeHelpers, WidgetsBindingObserver {
  static const List<String> _levelNames = ['off', 'light', 'moderate', 'aggressive'];

  /// Sizes and entry counts per cache, refreshed after every action.
  Map<String, ({int? bytes, int? entries})> _snapshot = {};

  /// Process memory from the platform, KB per key. Android only.
  Map<String, int>? _memory;
  bool _busy = false;

  bool get _canReadMemory => !kIsWeb && !kIsDesktop && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the background is the interesting moment: it is when the
  /// automatic purge has run and content is reloading.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final snapshot = CacheSvc.snapshot();
    Map<String, int>? memory;
    if (_canReadMemory) {
      try {
        memory = await MethodChannelSvc.actions.memoryStats();
      } catch (_) {
        memory = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _memory = memory;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLevel(String key, String value) async {
    final settings = SettingsSvc.settings;
    switch (key) {
      case kCachePurgeBackgroundLevelKey:
        settings.cachePurgeBackgroundLevel.value = value;
        break;
      case kCachePurgeMemoryPressureLevelKey:
        settings.cachePurgeMemoryPressureLevel.value = value;
        break;
    }
    CacheSvc.loadFromSettings();
    await settings.saveOneAsync(key);
  }

  Future<void> _setExcluded(String id, bool excluded) async {
    final settings = SettingsSvc.settings;
    final ids = parseExcludedCacheIds(settings.cachePurgeExcludedCaches.value);
    if (excluded) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    settings.cachePurgeExcludedCaches.value = ids.join(',');
    CacheSvc.loadFromSettings();
    await settings.saveOneAsync(kCachePurgeExcludedCachesKey);
  }

  String _sizeLabel(String id) {
    final entry = _snapshot[id];
    if (entry == null) return 'not measured';
    final parts = <String>[];
    if (entry.bytes != null) parts.add(formatCacheBytes(entry.bytes!));
    if (entry.entries != null) parts.add('${entry.entries} entr${entry.entries == 1 ? 'y' : 'ies'}');
    return parts.isEmpty ? 'not measurable' : parts.join(', ');
  }

  String _mb(int? kb) => kb == null || kb < 0 ? '?' : '${(kb / 1024).toStringAsFixed(1)} MB';

  String _memoryLabel() {
    final m = _memory;
    if (m == null) return 'Tap to read process memory.';
    return 'PSS ${_mb(m['pss'])}  ·  graphics ${_mb(m['graphics'])}  ·  Dart/native heap ${_mb(m['nativeHeap'])}\n'
        'Java heap ${_mb(m['javaHeap'])}  ·  code ${_mb(m['code'])}  ·  private other ${_mb(m['privateOther'])}\n'
        'Tap to refresh. Compare against the Dart-side numbers below: the gap is engine and GPU memory.';
  }

  String _levelHelp(String level) {
    switch (level) {
      case 'off':
        return 'nothing is released';
      case 'light':
        return 'images trimmed to 25%, engine caches purged';
      case 'moderate':
        return 'everything except inline video players';
      case 'aggressive':
        return 'everything, including inline video players';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsSvc.settings;
    return SettingsScaffold(
      title: "Cache Tuning",
      initialHeader: "Automatic Purging",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(backgroundColor: tileColor, children: [
                Obx(() => SettingsOptions<String>(
                      initial: settings.cachePurgeBackgroundLevel.value,
                      onChanged: (val) async {
                        if (val == null) return;
                        await _saveLevel(kCachePurgeBackgroundLevelKey, val);
                      },
                      options: _levelNames,
                      title: "On Background",
                      subtitle: "Runs when the app is sent to the background. "
                          "Currently: ${_levelHelp(settings.cachePurgeBackgroundLevel.value)}.",
                      secondaryColor: headerColor,
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.arrow_down_right_arrow_up_left,
                        materialIcon: Icons.cleaning_services_outlined,
                        containerColor: Colors.teal,
                      ),
                    )),
                Obx(() => SettingsOptions<String>(
                      initial: settings.cachePurgeMemoryPressureLevel.value,
                      onChanged: (val) async {
                        if (val == null) return;
                        await _saveLevel(kCachePurgeMemoryPressureLevelKey, val);
                      },
                      options: _levelNames,
                      title: "On Memory Pressure",
                      subtitle: "Runs when the OS reports low memory. "
                          "Currently: ${_levelHelp(settings.cachePurgeMemoryPressureLevel.value)}.",
                      secondaryColor: headerColor,
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.exclamationmark_triangle,
                        materialIcon: Icons.warning_amber_outlined,
                        containerColor: Colors.orange,
                      ),
                    )),
              ]),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Caches"),
              SettingsSection(backgroundColor: tileColor, children: [
                for (final cache in CacheSvc.caches)
                  Obx(() {
                    final excluded = parseExcludedCacheIds(settings.cachePurgeExcludedCaches.value);
                    return SettingsSwitch(
                      initialVal: !excluded.contains(cache.id),
                      onChanged: (val) => _setExcluded(cache.id, !val),
                      title: cache.id,
                      subtitle: "${cache.description}. ${_sizeLabel(cache.id)}. "
                          "Off leaves it alone during automatic purges.",
                      isThreeLine: true,
                      backgroundColor: tileColor,
                    );
                  }),
              ]),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Purge Now"),
              SettingsSection(backgroundColor: tileColor, children: [
                for (final level in CachePurgeLevel.values)
                  SettingsTile(
                    onTap: _busy ? null : () => _run(() => CacheSvc.purge(level, reason: 'developer tools')),
                    title: "Purge ${level.name}",
                    subtitle: "${_levelHelp(level.name)}. Honours the per-cache switches above.",
                    isThreeLine: true,
                    backgroundColor: tileColor,
                  ),
                for (final cache in CacheSvc.caches)
                  SettingsTile(
                    onTap: _busy ? null : () => _run(() => CacheSvc.clear(cache.id, reason: 'developer tools')),
                    title: "Clear ${cache.id} only",
                    subtitle: _sizeLabel(cache.id),
                    backgroundColor: tileColor,
                  ),
                SettingsTile(
                  onTap: _busy
                      ? null
                      : () => _run(() => CacheSvc.apply(
                            {'images': const CachePurgeAction.trimToFraction(0.25)},
                            reason: 'developer tools',
                          )),
                  title: "Trim images to 25%",
                  subtitle: "What the light level does to the image cache, on its own.",
                  backgroundColor: tileColor,
                ),
              ]),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Measurements"),
              SettingsSection(backgroundColor: tileColor, children: [
                if (_canReadMemory)
                  SettingsTile(
                    onTap: _refresh,
                    title: "Process memory",
                    subtitle: _memoryLabel(),
                    isThreeLine: true,
                    backgroundColor: tileColor,
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.memories,
                      materialIcon: Icons.memory,
                      containerColor: Colors.blueGrey,
                    ),
                  ),
                Obx(() {
                  final report = CacheSvc.lastReport.value;
                  return SettingsTile(
                    onTap: _refresh,
                    title: "Last purge",
                    subtitle: report == null
                        ? "No purge has run since launch. Background the app and come back, or use Purge Now."
                        : report.summarize(),
                    isThreeLine: true,
                    backgroundColor: tileColor,
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.doc_text,
                      materialIcon: Icons.receipt_long_outlined,
                      containerColor: Colors.indigo,
                    ),
                  );
                }),
              ]),
              if (kIsDesktop) const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}
