import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/theme_studio_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/preset_theme_dialogs.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Two grouped sections — Light Themes and Dark Themes — each with a
/// prominent full-width Default card (Bright White / OLED Dark) and a
/// horizontal scroll of other presets, custom themes, and action cards.
///
/// Rendering is deferred until after the first frame so the page appears
/// immediately on navigation rather than blocking for the full build time.
class ThemeSelectorSection extends StatefulWidget {
  const ThemeSelectorSection({super.key, required this.controller});

  final ThemeStudioController controller;

  @override
  State<ThemeSelectorSection> createState() => _ThemeSelectorSectionState();
}

class _ThemeSelectorSectionState extends State<ThemeSelectorSection> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();
    if (!_ready) {
      sw.stop();
      // Approximate placeholder height keeps the page layout stable once
      // content appears. Adjust if the rendered height changes significantly.
      return const SizedBox(height: 380);
    }

    final controller = widget.controller;
    final all = controller.allThemes;

    // Partition by brightness
    final lightAll = all
        .where(
            (t) => t.data.colorScheme.brightness == Brightness.light && controller.includeInGeneralThemeLists(t.name))
        .toList();
    final darkAll = all
        .where((t) => t.data.colorScheme.brightness == Brightness.dark && controller.includeInGeneralThemeLists(t.name))
        .toList();
    final adaptiveLight =
        controller.adaptiveThemes.where((t) => t.data.colorScheme.brightness == Brightness.light).toList();
    final adaptiveDark =
        controller.adaptiveThemes.where((t) => t.data.colorScheme.brightness == Brightness.dark).toList();

    // Canonical defaults shown full-width; everything else goes in the scroll row
    final brightWhite = lightAll.firstWhereOrNull((t) => t.name == "Bright White");
    final oledDark = darkAll.firstWhereOrNull((t) => t.name == "OLED Dark");
    final materialLight = lightAll.where((t) => ThemesService.isMaterialYouThemeName(t.name)).toList()
      ..sort(
          (a, b) => ThemesService.materialYouSortOrder(a.name).compareTo(ThemesService.materialYouSortOrder(b.name)));
    final materialDark = darkAll.where((t) => ThemesService.isMaterialYouThemeName(t.name)).toList()
      ..sort(
          (a, b) => ThemesService.materialYouSortOrder(a.name).compareTo(ThemesService.materialYouSortOrder(b.name)));
    final lightOther =
        lightAll.where((t) => t.name != "Bright White" && !ThemesService.isMaterialYouThemeName(t.name)).toList();
    final darkOther =
        darkAll.where((t) => t.name != "OLED Dark" && !ThemesService.isMaterialYouThemeName(t.name)).toList();

    final pendingChanges = controller.pendingChanges.value;
    final bool showDark = controller.previewDark.value;

    final widgetTree = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeGroup(
            key: ValueKey<bool>(showDark),
            controller: controller,
            title: showDark ? "Dark Themes" : "Light Themes",
            defaultTheme: showDark ? oledDark : brightWhite,
            adaptiveThemes: showDark ? adaptiveDark : adaptiveLight,
            materialYouThemes: showDark ? materialDark : materialLight,
            otherThemes: showDark ? darkOther : lightOther,
            isForDark: showDark,
            activeTheme: showDark ? controller.darkTheme : controller.lightTheme,
            appliedThemeName: showDark ? controller.appliedDarkName : controller.appliedLightName,
            pendingChanges: pendingChanges,
          ),
        ],
      ),
    );
    sw.stop();
    return widgetTree;
  }
}

// ─── One mode group (Light or Dark) ───────────────────────────────────────────

class _ModeGroup extends StatefulWidget {
  const _ModeGroup({
    super.key,
    required this.controller,
    required this.title,
    required this.defaultTheme,
    required this.adaptiveThemes,
    required this.materialYouThemes,
    required this.otherThemes,
    required this.isForDark,
    required this.activeTheme,
    required this.appliedThemeName,
    required this.pendingChanges,
  });

  final ThemeStudioController controller;
  final String title;
  final ThemeStruct? defaultTheme;
  final List<ThemeStruct> adaptiveThemes;
  final List<ThemeStruct> materialYouThemes;
  final List<ThemeStruct> otherThemes;
  final bool isForDark;
  final ThemeStruct activeTheme;
  final String appliedThemeName;
  final bool pendingChanges;

  @override
  State<_ModeGroup> createState() => _ModeGroupState();
}

class _ModeGroupState extends State<_ModeGroup> {
  static const int _presetPageSize = 10;
  int _visiblePresetCount = _presetPageSize;
  late List<ThemeStruct> _presets;
  late List<ThemeStruct> _custom;

  bool get _selectionIsPending => widget.pendingChanges && widget.activeTheme.name != widget.appliedThemeName;

  @override
  void initState() {
    super.initState();
    _recomputeThemeBuckets();
  }

  @override
  void didUpdateWidget(covariant _ModeGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.otherThemes, widget.otherThemes)) {
      _recomputeThemeBuckets();
    }
  }

  void _recomputeThemeBuckets() {
    _presets = widget.otherThemes.where((t) => t.isPreset).toList(growable: false);
    _custom = widget.otherThemes.where((t) => !t.isPreset).toList(growable: false);
    if (_visiblePresetCount > _presets.length) {
      _visiblePresetCount = _presets.length;
    } else if (_visiblePresetCount < _presetPageSize) {
      _visiblePresetCount = _presets.isEmpty ? 0 : _presetPageSize.clamp(0, _presets.length).toInt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();
    final dialogs = PresetThemeDialogs(
      controller: widget.controller,
      isForDark: widget.isForDark,
      showImportDialog: _showImportDialog,
    );

    final presets = _presets;
    final custom = _custom;

    final bool isCurrentMode = widget.controller.isDark.value == widget.isForDark;

    final widgetTree = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: context.theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isCurrentMode ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => dialogs.showImportDialog(context),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: context.theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text("Import", style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: () => dialogs.showCreateDialog(context),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 13),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("New"),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 11, color: context.theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              "Tap and hold on a theme for more options",
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: context.theme.colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.defaultTheme != null) ...[
          const _SubLabel("Default"),
          const SizedBox(height: 6),
          _DefaultCard(
            struct: widget.defaultTheme!,
            isActive: widget.activeTheme.name == widget.defaultTheme!.name,
            isApplied: widget.appliedThemeName == widget.defaultTheme!.name,
            selectionIsPending: _selectionIsPending,
            onTap: () => widget.controller.applyTheme(context, widget.defaultTheme!),
            onLongPress: () => dialogs.showContextMenu(context, widget.defaultTheme!),
            onSecondaryTap: () => dialogs.showContextMenu(context, widget.defaultTheme!),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.adaptiveThemes.isNotEmpty) ...[
          const _SubLabel("Adaptive Theme From Custom Background"),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: RepaintBoundary(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.adaptiveThemes.length,
                itemBuilder: (ctx, i) {
                  final t = widget.adaptiveThemes[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ThemeCard(
                      struct: t,
                      titleOverride: widget.controller.displayNameForThemeName(t.name),
                      isActive: widget.activeTheme.name == t.name,
                      isApplied: widget.appliedThemeName == t.name,
                      selectionIsPending: _selectionIsPending,
                      onTap: () => widget.controller.applyTheme(context, t),
                      onLongPress: () => dialogs.showContextMenu(context, t),
                      onSecondaryTap: () => dialogs.showContextMenu(context, t),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.materialYouThemes.isNotEmpty) ...[
          const _SubLabel("Material You"),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: RepaintBoundary(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.materialYouThemes.length,
                itemBuilder: (ctx, i) {
                  final t = widget.materialYouThemes[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ThemeCard(
                      struct: t,
                      titleOverride: widget.controller.displayNameForThemeName(t.name),
                      isActive: widget.activeTheme.name == t.name,
                      isApplied: widget.appliedThemeName == t.name,
                      selectionIsPending: _selectionIsPending,
                      onTap: () => widget.controller.applyTheme(context, t),
                      onLongPress: () => dialogs.showContextMenu(context, t),
                      onSecondaryTap: () => dialogs.showContextMenu(context, t),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (custom.isNotEmpty) ...[
          const _SubLabel("Custom"),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: custom.length,
              itemBuilder: (ctx, i) {
                final t = custom[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _ThemeCard(
                    struct: t,
                    titleOverride: widget.controller.displayNameForThemeName(t.name),
                    isActive: widget.activeTheme.name == t.name,
                    isApplied: widget.appliedThemeName == t.name,
                    selectionIsPending: _selectionIsPending,
                    onTap: () => widget.controller.applyTheme(context, t),
                    onLongPress: () => dialogs.showContextMenu(context, t),
                    onSecondaryTap: () => dialogs.showContextMenu(context, t),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (presets.isNotEmpty) ...[
          const _SubLabel("More"),
          const SizedBox(height: 6),
          _PaginatedPresetRow(
            themes: presets,
            visibleCount: _visiblePresetCount,
            onLoadMore: _loadMorePresets,
            cardBuilder: (t) => _ThemeCard(
              struct: t,
              titleOverride: widget.controller.displayNameForThemeName(t.name),
              isActive: widget.activeTheme.name == t.name,
              isApplied: widget.appliedThemeName == t.name,
              selectionIsPending: _selectionIsPending,
              onTap: () => widget.controller.applyTheme(context, t),
              onLongPress: () => dialogs.showContextMenu(context, t),
              onSecondaryTap: () => dialogs.showContextMenu(context, t),
            ),
          ),
        ],
      ],
    );
    sw.stop();
    return widgetTree;
  }

  void _loadMorePresets() {
    setState(() {
      _visiblePresetCount = (_visiblePresetCount + _presetPageSize).clamp(0, _presets.length).toInt();
    });
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ImportDialog(controller: widget.controller, pageContext: context),
    );
  }
}

class _PaginatedPresetRow extends StatefulWidget {
  const _PaginatedPresetRow({
    required this.themes,
    required this.visibleCount,
    required this.onLoadMore,
    required this.cardBuilder,
  });

  final List<ThemeStruct> themes;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final Widget Function(ThemeStruct theme) cardBuilder;

  @override
  State<_PaginatedPresetRow> createState() => _PaginatedPresetRowState();
}

class _PaginatedPresetRowState extends State<_PaginatedPresetRow> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (widget.visibleCount >= widget.themes.length) return;
    if (_scrollController.position.extentAfter < 180) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visibleCount.clamp(0, widget.themes.length);
    return SizedBox(
      height: 110,
      child: RepaintBoundary(
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: visible,
          itemBuilder: (ctx, i) {
            final t = widget.themes[i];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: widget.cardBuilder(t),
            );
          },
        ),
      ),
    );
  }
}

// ─── Sub-label ─────────────────────────────────────────────────────────────────

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.theme.textTheme.labelSmall?.copyWith(
        color: context.theme.colorScheme.outline,
        letterSpacing: 0.7,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─── Full-width default card ───────────────────────────────────────────────────

class _DefaultCard extends StatefulWidget {
  const _DefaultCard({
    required this.struct,
    required this.isActive,
    required this.isApplied,
    required this.selectionIsPending,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final ThemeStruct struct;
  final bool isActive;
  final bool isApplied;
  final bool selectionIsPending;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  @override
  State<_DefaultCard> createState() => _DefaultCardState();
}

class _DefaultCardState extends State<_DefaultCard> {
  bool _suppressNextTap = false;

  void _onLongPress() {
    _suppressNextTap = true;
    widget.onLongPress?.call();
  }

  void _onSecondaryTap() {
    _suppressNextTap = true;
    widget.onSecondaryTap?.call();
  }

  void _onTap() {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.struct.data.colorScheme;
    final bubbleColors = widget.struct.data.extension<BubbleColors>();
    final sentBubble = bubbleColors?.iMessageBubbleColor ?? cs.primary;
    final receivedBubble = bubbleColors?.receivedBubbleColor ?? cs.surfaceContainerHighest;
    // isPending: staged for this slot but not yet applied
    final isPending = widget.isActive && widget.selectionIsPending;
    // wasApplied: this is the current live theme but something else is staged
    final wasApplied = widget.isApplied && !widget.isActive;

    final borderColor = isPending
        ? context.theme.colorScheme.tertiary
        : widget.isActive
            ? context.theme.colorScheme.primary
            : wasApplied
                ? context.theme.colorScheme.secondary.withValues(alpha: 0.5)
                : context.theme.colorScheme.outline.withValues(alpha: 0.3);
    final borderWidth = (widget.isActive || wasApplied) ? 2.0 : 1.0;

    return GestureDetector(
      onTap: _onTap,
      onSecondaryTap: _onSecondaryTap,
      onLongPress: _onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: context.tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          children: [
            // 2×2 color swatch preview
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              child: SizedBox(
                width: 72,
                height: 60,
                child: _PalettePreview(
                  topLeft: sentBubble,
                  topRight: receivedBubble,
                  bottomLeft: cs.surface,
                  bottomRight: cs.surfaceContainerHighest,
                ),
              ),
            ),
            // Name + caption
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.struct.name,
                      style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Built-in default",
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Selection indicator
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _SelectionIcon(
                isActive: widget.isActive,
                isPending: isPending,
                wasApplied: wasApplied,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual theme card ─────────────────────────────────────────────────────

class _ThemeCard extends StatefulWidget {
  const _ThemeCard({
    required this.struct,
    required this.isActive,
    required this.isApplied,
    required this.selectionIsPending,
    required this.onTap,
    this.titleOverride,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final ThemeStruct struct;
  final bool isActive;
  final bool isApplied;
  final bool selectionIsPending;
  final VoidCallback onTap;
  final String? titleOverride;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _suppressNextTap = false;

  void _onLongPress() {
    _suppressNextTap = true;
    widget.onLongPress?.call();
  }

  void _onSecondaryTap() {
    _suppressNextTap = true;
    widget.onSecondaryTap?.call();
  }

  void _onTap() {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.struct.data.colorScheme;
    final bubbleColors = widget.struct.data.extension<BubbleColors>();
    final sentBubble = bubbleColors?.iMessageBubbleColor ?? cs.primary;
    final receivedBubble = bubbleColors?.receivedBubbleColor ?? cs.surfaceContainerHighest;
    final isPending = widget.isActive && widget.selectionIsPending;
    final wasApplied = widget.isApplied && !widget.isActive;

    final borderColor = isPending
        ? context.theme.colorScheme.tertiary
        : widget.isActive
            ? context.theme.colorScheme.primary
            : wasApplied
                ? context.theme.colorScheme.secondary.withValues(alpha: 0.5)
                : context.theme.colorScheme.outline.withValues(alpha: 0.3);
    final borderWidth = (widget.isActive || wasApplied) ? 2.0 : 1.0;

    return GestureDetector(
      onTap: _onTap,
      onSecondaryTap: _onSecondaryTap,
      onLongPress: _onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color swatch grid
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: SizedBox(
                height: 60,
                child: Stack(
                  children: [
                    _PalettePreview(
                      topLeft: sentBubble,
                      topRight: receivedBubble,
                      bottomLeft: cs.surface,
                      bottomRight: cs.surfaceContainerHighest,
                    ),
                    if (widget.isActive || wasApplied)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: _SelectionIcon(
                          isActive: widget.isActive,
                          isPending: isPending,
                          wasApplied: wasApplied,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Theme name
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  widget.titleOverride ?? widget.struct.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.labelSmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final Color topLeft;
  final Color topRight;
  final Color bottomLeft;
  final Color bottomRight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PalettePreviewPainter(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PalettePreviewPainter extends CustomPainter {
  const _PalettePreviewPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final Color topLeft;
  final Color topRight;
  final Color bottomLeft;
  final Color bottomRight;

  @override
  void paint(Canvas canvas, Size size) {
    final halfW = size.width / 2;
    final halfH = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, halfW, halfH), Paint()..color = topLeft);
    canvas.drawRect(Rect.fromLTWH(halfW, 0, halfW, halfH), Paint()..color = topRight);
    canvas.drawRect(Rect.fromLTWH(0, halfH, halfW, halfH), Paint()..color = bottomLeft);
    canvas.drawRect(Rect.fromLTWH(halfW, halfH, halfW, halfH), Paint()..color = bottomRight);
  }

  @override
  bool shouldRepaint(covariant _PalettePreviewPainter oldDelegate) {
    return topLeft != oldDelegate.topLeft ||
        topRight != oldDelegate.topRight ||
        bottomLeft != oldDelegate.bottomLeft ||
        bottomRight != oldDelegate.bottomRight;
  }
}

// ─── Selection icon (applied / pending / was-applied) ─────────────────────────

class _SelectionIcon extends StatelessWidget {
  const _SelectionIcon({
    required this.isActive,
    required this.isPending,
    required this.wasApplied,
    required this.size,
  });

  final bool isActive;
  final bool isPending;
  final bool wasApplied;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    if (isPending) {
      // Staged but not yet applied — shown with tertiary ring color + clock icon
      return Container(
        decoration: BoxDecoration(color: cs.tertiary, shape: BoxShape.circle),
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.schedule_rounded, size: size - 4, color: cs.onTertiary),
      );
    }
    if (isActive) {
      // Staged == applied; confirmed live selection
      return Container(
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.check, size: size - 4, color: cs.onPrimary),
      );
    }
    if (wasApplied) {
      // Currently live but being replaced by pending selection
      return Icon(Icons.check_circle_outline_rounded, size: size, color: cs.secondary.withValues(alpha: 0.55));
    }
    return Icon(Icons.radio_button_unchecked, size: size, color: cs.outline.withValues(alpha: 0.5));
  }
}

// ─── Import dialog ─────────────────────────────────────────────────────────────

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.controller, required this.pageContext});

  final ThemeStudioController controller;
  final BuildContext pageContext;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _textController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    final path = result.files.first.path;
    String? json;
    if (bytes != null) {
      json = String.fromCharCodes(bytes);
    } else if (path != null) {
      json = await File(path).readAsString();
    }
    if (json != null) _textController.text = json;
  }

  Future<void> _doImport() async {
    final json = _textController.text.trim();
    if (json.isEmpty) return;
    setState(() => _loading = true);
    final theme = await widget.controller.importThemeFromJson(json);
    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (theme != null) {
      showSnackbar("Imported", "Theme \"${theme.name}\" imported successfully", type: SnackbarType.success);
    } else {
      showSnackbar("Error", "Could not parse theme — make sure it's a valid exported JSON", type: SnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      title: Text("Import Theme", style: context.theme.textTheme.titleLarge),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Paste the exported theme JSON below, or pick a .json file.",
              style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '{ "name": "...", "data": { ... } }',
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: context.theme.colorScheme.outline)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: context.theme.colorScheme.primary)),
              ),
              style: context.theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text("Pick File"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel", style: TextStyle(color: context.theme.colorScheme.primary)),
        ),
        FilledButton(
          onPressed: _loading ? null : _doImport,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Import"),
        ),
      ],
    );
  }
}
