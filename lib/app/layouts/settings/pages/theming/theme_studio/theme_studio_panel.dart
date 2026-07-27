import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/color_editor_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/preset_theme_strip.dart'
    show ThemeSelectorSection;
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/theme_management_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/theme_preview_card.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/typography_editor.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ─── Controller ───────────────────────────────────────────────────────────────

class ThemeStudioPanelConfig {
  const ThemeStudioPanelConfig({
    this.initialLightThemeName,
    this.initialDarkThemeName,
    this.adaptiveImagePath,
    this.adaptiveThemeScopeKey,
    this.onApply,
  });

  final String? initialLightThemeName;
  final String? initialDarkThemeName;
  final String? adaptiveImagePath;
  final String? adaptiveThemeScopeKey;
  final Future<void> Function(ThemeStruct lightTheme, ThemeStruct darkTheme)? onApply;

  bool get isChatScoped => onApply != null;
}

class ThemeStudioController extends StatefulController {
  ThemeStudioController({this.config});

  final ThemeStudioPanelConfig? config;

  late ThemeStruct lightTheme;
  late ThemeStruct darkTheme;

  /// The names of what's actually live in the running app (saved to prefs).
  String appliedLightName = '';
  String appliedDarkName = '';

  final RxBool isDark = false.obs;

  /// Controls which theme variant the preview shows — independent of the
  /// actively-selected editing theme.
  final RxBool previewDark = false.obs;

  final RxList<ThemeStruct> allThemes = <ThemeStruct>[].obs;
  final RxList<ThemeStruct> adaptiveThemes = <ThemeStruct>[].obs;

  /// Bumped when active theme data (colors, font, sizes) changes, or when the
  /// active theme selection changes.
  final RxInt themeDataVersion = 0.obs;

  /// Bumped when the list of available themes changes (add/remove/rename/select).
  final RxInt themeListVersion = 0.obs;

  /// True when changes have been staged but not yet applied to the running UI.
  final RxBool pendingChanges = false.obs;

  ThemeStruct get activeTheme => isDark.value ? darkTheme : lightTheme;

  ThemeStruct get previewTheme => previewDark.value ? darkTheme : lightTheme;

  bool get isEditable => !activeTheme.isPreset && !ThemesService.isAdaptiveBackgroundThemeName(activeTheme.name);
  bool get isChatScoped => config?.isChatScoped == true;
  Set<String> get adaptiveThemeNames => adaptiveThemes.map((theme) => theme.name).toSet();
  String? get _sourceLightThemeName => appliedLightName.isNotEmpty ? appliedLightName : config?.initialLightThemeName;
  String? get _sourceDarkThemeName => appliedDarkName.isNotEmpty ? appliedDarkName : config?.initialDarkThemeName;

  String displayNameForThemeName(String name) {
    if (ThemesService.isAdaptiveBackgroundThemeName(name)) {
      return ThemesService.adaptiveBackgroundThemeDisplayName(name);
    }
    if (ThemesService.isMaterialYouThemeName(name)) {
      return ThemesService.materialYouDisplayName(name);
    }
    return name;
  }

  bool includeInGeneralThemeLists(String name) {
    if (!ThemesService.isAdaptiveBackgroundThemeName(name)) return true;
    if (adaptiveThemeNames.contains(name)) return false;
    return name == lightTheme.name || name == darkTheme.name || name == appliedLightName || name == appliedDarkName;
  }

  void init(bool isDarkMode) {
    isDark.value = isDarkMode;
    previewDark.value = isDarkMode;
    _reload();
    appliedLightName = lightTheme.name;
    appliedDarkName = darkTheme.name;
    if (config?.adaptiveImagePath != null && config?.adaptiveThemeScopeKey != null) {
      unawaited(_loadAdaptiveThemes());
    }
  }

  void _reload() {
    lightTheme = ThemeStruct.resolveByName(_sourceLightThemeName, Brightness.light);
    darkTheme = ThemeStruct.resolveByName(_sourceDarkThemeName, Brightness.dark);
    allThemes.value = ThemeStruct.getThemes();
    themeDataVersion.value++;
    themeListVersion.value++;
  }

  /// Refreshes only the list of all themes without resetting the staged
  /// light/dark selections.
  void _reloadThemesList() {
    allThemes.value = ThemeStruct.getThemes();
    themeListVersion.value++;
  }

  Future<void> _loadAdaptiveThemes() async {
    final imagePath = config?.adaptiveImagePath;
    final scopeKey = config?.adaptiveThemeScopeKey;
    if (imagePath == null || scopeKey == null) return;

    adaptiveThemes.value = await ThemesService.upsertAdaptiveBackgroundThemesFromImage(
      imagePath,
      scopeKey: scopeKey,
    );
    _reloadThemesList();

    if (ThemesService.isAdaptiveBackgroundThemeName(lightTheme.name)) {
      lightTheme = ThemeStruct.resolveByName(lightTheme.name, Brightness.light);
    }
    if (ThemesService.isAdaptiveBackgroundThemeName(darkTheme.name)) {
      darkTheme = ThemeStruct.resolveByName(darkTheme.name, Brightness.dark);
    }
    themeDataVersion.value++;
  }

  void bump() {
    themeDataVersion.value++;
  }

  // ── Theme selection ────────────────────────────────────────────────────────

  /// Stages a theme selection for preview. Call [applyChanges] to make it live.
  void applyTheme(BuildContext context, ThemeStruct struct) {
    final isThemeDark = struct.data.colorScheme.brightness == Brightness.dark;
    isDark.value = isThemeDark;
    previewDark.value = isThemeDark;
    if (isThemeDark) {
      darkTheme = struct;
    } else {
      lightTheme = struct;
    }
    themeDataVersion.value++;
    themeListVersion.value++;
    pendingChanges.value = true;
  }

  // ── Apply staged changes to the running app ────────────────────────────────

  Future<void> applyChanges(BuildContext context) async {
    lightTheme.save();
    darkTheme.save();
    appliedLightName = lightTheme.name;
    appliedDarkName = darkTheme.name;
    if (config?.onApply != null) {
      await config!.onApply!(lightTheme, darkTheme);
    } else {
      await ThemeSvc.changeTheme(context, light: lightTheme);
      await ThemeSvc.changeTheme(context, dark: darkTheme);
      EventDispatcherSvc.emit('theme-update', null);
    }
    pendingChanges.value = false;
  }

  /// Discards all staged edits by reloading themes from the DB.
  void discardChanges() {
    _reload();
    if (config?.adaptiveImagePath != null && config?.adaptiveThemeScopeKey != null) {
      unawaited(_loadAdaptiveThemes());
    }
    pendingChanges.value = false;
  }

  // ── Color editing ──────────────────────────────────────────────────────────

  void updateColorKey(BuildContext context, String colorKey, Color newColor) {
    if (!isEditable) return;
    final map = activeTheme.toMap();
    map["data"]["colorScheme"][colorKey] = newColor.toARGB32();
    activeTheme.data = ThemeStruct.fromMap(map).data;
    themeDataVersion.value++;
    pendingChanges.value = true;
  }

  // ── Typography ─────────────────────────────────────────────────────────────

  void updateFont(BuildContext context, String fontName) {
    final map = activeTheme.toMap();
    map["data"]["textTheme"]["font"] = fontName;
    activeTheme.googleFont = fontName;
    activeTheme.data = ThemeStruct.fromMap(map).data;
    // Do not save to DB here — font changes are staged in memory only and
    // persisted when the user explicitly clicks Apply (applyChanges). This
    // ensures re-entering the page always shows the currently applied font.
    themeDataVersion.value++;
    pendingChanges.value = true;
  }

  void updateTextSize(BuildContext context, String key, double multiplier) {
    final map = activeTheme.toMap();
    final keys = key == 'master' ? activeTheme.textSizes.keys.toList() : [key];
    for (final k in keys) {
      map["data"]["textTheme"][k]['fontSize'] = ThemeStruct.defaultTextSizes[k]! * multiplier;
    }
    activeTheme.data = ThemeStruct.fromMap(map).data;
    themeDataVersion.value++;
    pendingChanges.value = true;
  }

  // ── Theme management ───────────────────────────────────────────────────────

  ThemeStruct createTheme(BuildContext context, String name, {bool? forDark}) {
    final darkMode = forDark ?? isDark.value;
    isDark.value = darkMode;
    previewDark.value = darkMode;
    final tuple = ThemeSvc.getStructsFromData(activeTheme.data, activeTheme.data);
    final newData = darkMode ? tuple.dark : tuple.light;
    final newTheme = ThemeStruct(name: name, themeData: newData);
    newTheme.save();
    if (darkMode) {
      darkTheme = newTheme;
    } else {
      lightTheme = newTheme;
    }
    _reloadThemesList();
    themeDataVersion.value++;
    pendingChanges.value = true;
    return newTheme;
  }

  /// Clones [source] into a new theme with [name] and makes it the staged
  /// active theme for its brightness mode.
  ThemeStruct cloneTheme(String name, ThemeStruct source) {
    final clone = ThemeStruct(
      name: name,
      themeData: source.data,
      gradientBg: source.gradientBg,
      googleFont: source.googleFont,
    );
    clone.save();
    final isDarkClone = clone.data.colorScheme.brightness == Brightness.dark;
    isDark.value = isDarkClone;
    previewDark.value = isDarkClone;
    if (isDarkClone) {
      darkTheme = clone;
    } else {
      lightTheme = clone;
    }
    _reloadThemesList();
    themeDataVersion.value++;
    pendingChanges.value = true;
    return clone;
  }

  Future<bool> renameTheme(BuildContext context, String newName) async {
    if (activeTheme.isPreset || newName.isEmpty) return false;
    if (ThemeStruct.findOne(newName) != null) return false;
    final oldName = activeTheme.name;
    activeTheme.name = newName;
    activeTheme.save();
    if (PrefsSvc.theme.getSelectedLightTheme() == oldName) {
      await PrefsSvc.theme.setSelectedLightTheme(newName);
    }
    if (PrefsSvc.theme.getSelectedDarkTheme() == oldName) {
      await PrefsSvc.theme.setSelectedDarkTheme(newName);
    }
    // Keep applied name tracking in sync if the applied theme was renamed.
    if (appliedLightName == oldName) appliedLightName = newName;
    if (appliedDarkName == oldName) appliedDarkName = newName;
    _reloadThemesList();
    return true;
  }

  void generateFromSeed(BuildContext context, Color seed) {
    if (!isEditable) return;
    final brightness = isDark.value ? Brightness.dark : Brightness.light;
    final swatch = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    activeTheme.data = activeTheme.data.copyWith(colorScheme: swatch);
    themeDataVersion.value++;
    pendingChanges.value = true;
  }

  Future<void> generateFromImage(BuildContext context) async {
    if (!isEditable) return;
    final res =
        await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final image = MemoryImage(res.files.first.bytes!);
    final swatch = await ColorScheme.fromImageProvider(
        provider: image, brightness: isDark.value ? Brightness.dark : Brightness.light);
    activeTheme.data = activeTheme.data.copyWith(colorScheme: swatch);
    themeDataVersion.value++;
    pendingChanges.value = true;
  }

  void resetToDefault(BuildContext context) {
    if (activeTheme.isPreset) return;
    final defaultTheme = isDark.value
        ? ThemesService.defaultThemes.firstWhere((e) => e.name == "OLED Dark")
        : ThemesService.defaultThemes.firstWhere((e) => e.name == "Bright White");
    activeTheme.data = defaultTheme.data;
    themeDataVersion.value++;
    pendingChanges.value = true;
  }

  Future<void> deleteTheme(BuildContext context) async {
    if (activeTheme.isPreset) return;
    activeTheme.delete();
    if (isChatScoped) {
      darkTheme = ThemeStruct.resolveByName(_sourceDarkThemeName, Brightness.dark);
      lightTheme = ThemeStruct.resolveByName(_sourceLightThemeName, Brightness.light);
    } else if (isDark.value) {
      darkTheme = await ThemeSvc.revertToPreviousDarkTheme();
      await ThemeSvc.changeTheme(context, dark: darkTheme);
    } else {
      lightTheme = await ThemeSvc.revertToPreviousLightTheme();
      await ThemeSvc.changeTheme(context, light: lightTheme);
    }
    _reload();
    EventDispatcherSvc.emit('theme-update', null);
  }

  String exportThemeJson() {
    return const JsonEncoder.withIndent('  ').convert(activeTheme.toMap());
  }

  Future<ThemeStruct?> importThemeFromJson(String json) async {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      // Remove source device's ROWID so ObjectBox assigns a new one
      map["ROWID"] = null;
      final imported = ThemeStruct.fromMap(map);
      // Resolve name conflict with auto-suffix
      String name = imported.name;
      int suffix = 2;
      while (ThemeStruct.findOne(name) != null) {
        name = "${imported.name} ($suffix)";
        suffix++;
      }
      final finalTheme = ThemeStruct(
        name: name,
        themeData: imported.data,
        gradientBg: imported.gradientBg,
        googleFont: imported.googleFont,
      );
      finalTheme.save();
      _reload();
      return finalTheme;
    } catch (_) {
      return null;
    }
  }
}

// ─── Panel ────────────────────────────────────────────────────────────────────

class ThemeStudioPanel extends CustomStateful<ThemeStudioController> {
  ThemeStudioPanel({
    super.key,
    this.config,
  }) : super(parentController: Get.put(ThemeStudioController(config: config)));

  final ThemeStudioPanelConfig? config;

  @override
  State<StatefulWidget> createState() => _ThemeStudioPanelState();
}

class _ThemeStudioPanelState extends CustomState<ThemeStudioPanel, void, ThemeStudioController> {
  bool _initialized = false;

  /// False until the first frame is committed. Colors / Typography / Manage
  /// sections are deferred behind this flag so the visible content (preview +
  /// theme selector) can appear without blocking on below-fold layout work.
  final ValueNotifier<bool> _contentReady = ValueNotifier<bool>(false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      controller.init(ThemeSvc.inDarkMode(context));
      // Defer below-fold sections two frames out:
      //  - Frame 2: ThemeSelectorSection builds its full theme card list.
      //  - Frame 3: Colors/Typography/Manage sections appear.
      // Using a nested postFrameCallback ensures they never land in the same
      // rasterize pass, keeping each frame small.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _contentReady.value = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _contentReady.dispose();
    super.dispose();
  }

  /// Shows a dialog asking the user what to do with unsaved changes.
  /// Returns true if navigation should proceed (discard or apply+navigate).
  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showBBDialog<_PendingAction>(
      context: context,
      title: "Unsaved Changes",
      body: "You have pending changes that haven't been applied. What would you like to do?",
      actions: [
        BBDialogAction(
          text: "Keep Editing",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_PendingAction.cancel),
        ),
        BBDialogAction(
          text: "Discard",
          isDestructive: true,
          color: context.theme.colorScheme.error,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_PendingAction.discard),
        ),
        BBDialogAction(
          text: "Apply & Exit",
          isDefault: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_PendingAction.apply),
        ),
      ],
    );
    if (result == _PendingAction.apply && context.mounted) {
      await controller.applyChanges(context);
      return true;
    }
    if (result == _PendingAction.discard && context.mounted) {
      controller.discardChanges();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!controller.pendingChanges.value) {
          Navigator.of(context).pop();
          return;
        }
        final shouldPop = await _confirmDiscard(context);
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Obx(() {
        final hasPending = controller.pendingChanges.value;
        return SettingsScaffold(
          title: "Theme Studio",
          initialHeader: null,
          iosSubtitle: iosSubtitle,
          materialSubtitle: materialSubtitle,
          tileColor: tileColor,
          headerColor: headerColor,
          leading: hasPending
              ? _PendingBackButton(
                  onPressed: () => _confirmDiscard(context).then((ok) {
                        if (ok && context.mounted) Navigator.of(context).pop();
                      }))
              : null,
          actions: hasPending
              ? [
                  TextButton(
                    onPressed: () => controller.discardChanges(),
                    child: Text("Discard", style: TextStyle(color: context.theme.colorScheme.error)),
                  ),
                  TextButton(
                    onPressed: () => controller.applyChanges(context),
                    child: const Text("Apply"),
                  ),
                ]
              : [],
          fab: hasPending
              ? FloatingActionButton.extended(
                  onPressed: () => controller.applyChanges(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text("Apply"),
                )
              : null,
          bodySlivers: [
            // Global Light/Dark page toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Center(
                  child: _PreviewToggle(controller: controller),
                ),
              ),
            ),

            // Live preview
            SliverToBoxAdapter(
              child: Obx(() {
                controller.themeDataVersion.value;
                controller.previewDark.value;
                // Also subscribe to skin so the preview rebuilds when the user
                // switches between iOS / Material / Samsung themes.
                SettingsSvc.settings.skin.value;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.theme.colorScheme.outline.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: RepaintBoundary(
                      child: ThemePreviewCard(struct: controller.previewTheme),
                    ),
                  ),
                );
              }),
            ),

            // Themes
            SliverToBoxAdapter(child: _sectionHeader(context, "Themes")),
            SliverToBoxAdapter(
              child: Obx(() {
                controller.themeListVersion.value;
                controller.pendingChanges.value;
                controller.previewDark.value;
                return ThemeSelectorSection(controller: controller);
              }),
            ),

            SliverToBoxAdapter(
              child: ValueListenableBuilder<bool>(
                valueListenable: _contentReady,
                builder: (context, ready, _) {
                  if (!ready) return const SizedBox.shrink();
                  return _DeferredThemeStudioSections(
                    controller: controller,
                    sectionHeaderBuilder: _sectionHeader,
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      }),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6, left: 20, right: 20),
      child: Text(
        text.toUpperCase(),
        style: context.theme.textTheme.bodySmall?.copyWith(
          color: context.theme.colorScheme.outline,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DeferredThemeStudioSections extends StatelessWidget {
  const _DeferredThemeStudioSections({
    required this.controller,
    required this.sectionHeaderBuilder,
  });

  final ThemeStudioController controller;
  final Widget Function(BuildContext context, String text) sectionHeaderBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeaderBuilder(context, "Colors"),
        Obx(() {
          controller.themeDataVersion.value;
          if (!controller.isEditable) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: context.theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "To customize the app colors, create a new theme.",
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        Obx(() {
          controller.themeDataVersion.value;
          return _ColorEditorBody(controller: controller);
        }),
        sectionHeaderBuilder(context, "Typography"),
        Obx(() {
          controller.themeDataVersion.value;
          return TypographyEditor(controller: controller);
        }),
        sectionHeaderBuilder(context, "Manage Theme"),
        Obx(() {
          controller.themeListVersion.value;
          return ThemeManagementSection(controller: controller);
        }),
      ],
    );
  }
}

// ─── Preview light/dark toggle ────────────────────────────────────────────────

class _PreviewToggle extends StatelessWidget {
  const _PreviewToggle({required this.controller});
  final ThemeStudioController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = controller.previewDark.value;
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tab(context, label: "Light", icon: Icons.light_mode_outlined, selected: !isDark, onTap: () {
              controller.previewDark.value = false;
              controller.isDark.value = false;
            }),
            _tab(context, label: "Dark", icon: Icons.dark_mode_outlined, selected: isDark, onTap: () {
              controller.previewDark.value = true;
              controller.isDark.value = true;
            }),
          ],
        ),
      );
    });
  }

  Widget _tab(BuildContext context,
      {required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    final cs = context.theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Color editor body ────────────────────────────────────────────────────────

class _ColorEditorBody extends StatelessWidget {
  const _ColorEditorBody({required this.controller});
  final ThemeStudioController controller;

  static const _groups = [
    ColorGroup(
      title: "Brand",
      icon: Icons.palette_outlined,
      pairs: [
        ColorPair("primary", "onPrimary"),
        ColorPair("primaryContainer", "onPrimaryContainer"),
        ColorPair("secondary", "onSecondary"),
        ColorPair("tertiaryContainer", "onTertiaryContainer"),
      ],
    ),
    ColorGroup(
      title: "Surfaces & Backgrounds",
      icon: Icons.layers_outlined,
      pairs: [
        ColorPair("background", "onBackground"),
        ColorPair("surface", "onSurface"),
        ColorPair("surfaceVariant", "onSurfaceVariant"),
        ColorPair("inverseSurface", "onInverseSurface"),
      ],
    ),
    ColorGroup(
      title: "Chat Bubbles",
      icon: Icons.chat_bubble_outline,
      pairs: [
        ColorPair("smsBubble", "onSmsBubble"),
      ],
    ),
    ColorGroup(
      title: "Semantic",
      icon: Icons.warning_amber_outlined,
      pairs: [
        ColorPair("error", "onError"),
        ColorPair("errorContainer", "onErrorContainer"),
      ],
    ),
    ColorGroup(
      title: "Borders & Outlines",
      icon: Icons.border_outer_outlined,
      pairs: [
        ColorPair("outline", null),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = controller.activeTheme.colors(controller.isDark.value, returnMaterialYou: false);
    final editable = controller.isEditable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _groups
            .map((group) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ColorEditorSection(
                    group: group,
                    colors: colors,
                    editable: editable,
                    controller: controller,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Helpers for pending-changes UX ──────────────────────────────────────────

enum _PendingAction { apply, discard, cancel }

/// Custom back button shown when there are pending changes. It triggers the
/// confirmation dialog rather than navigating directly.
class _PendingBackButton extends StatelessWidget {
  const _PendingBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 48,
        child: IconButton(
          iconSize: SettingsSvc.settings.skin.value != Skins.Material ? 30 : 24,
          icon: Obx(() => Icon(
                SettingsSvc.settings.skin.value != Skins.Material ? CupertinoIcons.back : Icons.arrow_back,
                color: context.theme.colorScheme.primary,
              )),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
