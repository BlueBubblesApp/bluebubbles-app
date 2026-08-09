import 'package:bluebubbles/app/layouts/settings/pages/server/imessage_stats/imessage_stats_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SamsungIMessageStatsPage extends CustomStateful<ServerManagementPanelController> {
  const SamsungIMessageStatsPage({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungIMessageStatsPageState();
}

class _SamsungIMessageStatsPageState
    extends CustomState<SamsungIMessageStatsPage, void, ServerManagementPanelController>
    with IMessageStatsHelpersMixin {
  bool _showRefreshSuccess = false;

  @override
  void initState() {
    super.initState();
    forceDelete = false;
  }

  Future<void> _handleRefresh() async {
    if (controller.isActiveStatsLoading()) return;
    final success = await controller.refreshSelectedStats();
    if (!mounted || !success) return;
    setState(() => _showRefreshSuccess = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _showRefreshSuccess = false);
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildStatCard(StatItemConfig item, dynamic rawValue) {
    final count = formatCount(rawValue);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      color: tileColor,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.containerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.materialIcon, color: item.containerColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              count,
              style: context.theme.textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: context.theme.textTheme.bodySmall!.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaRow(StatItemConfig item, dynamic rawValue) {
    final count = formatCount(rawValue);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      color: tileColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: item.containerColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.materialIcon, color: item.containerColor, size: 24),
        ),
        title: Text(item.label, style: context.theme.textTheme.bodyLarge),
        trailing: Text(
          count,
          style: context.theme.textTheme.titleMedium!.copyWith(
            color: context.theme.colorScheme.outline.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final activeStats = controller.getActiveStatsMap();
    final hasStats = activeStats.isNotEmpty;
    final isLoading = controller.isActiveStatsLoading();
    final error = controller.getActiveStatsError();

    if (isLoading && !hasStats) return _buildLoadingState();

    final gridItems = IMessageStatsHelpersMixin.kStatItems.where((e) => !e.isFullWidth).toList();
    final mediaItems = IMessageStatsHelpersMixin.kStatItems.where((e) => e.isFullWidth).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Center(
            child: SegmentedButton<IMessageStatsSource>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: context.theme.colorScheme.onSurface,
                selectedForegroundColor: context.theme.colorScheme.onPrimary,
                selectedBackgroundColor: context.theme.colorScheme.primary,
              ),
              segments: [
                const ButtonSegment(value: IMessageStatsSource.server, label: Text("Server")),
                const ButtonSegment(
                  value: IMessageStatsSource.local,
                  label: Text("Local DB"),
                  enabled: !kIsWeb,
                ),
              ],
              selected: {controller.selectedStatsSource.value},
              onSelectionChanged: (value) => controller.setStatsSource(value.first),
            ),
          ),
        ),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(
              "Local DB stats are unavailable on web builds.",
              style: context.theme.textTheme.bodySmall,
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(
              error,
              style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(
            "Totals",
            style: context.theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 0,
                runSpacing: 0,
                children: gridItems.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildStatCard(item, activeStats[item.key]),
                  );
                }).toList(),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            "Media",
            style: context.theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
        ...mediaItems.map((item) => _buildMediaRow(item, activeStats[item.key])),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "iMessage Stats",
      initialHeader: null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      actions: [
        Obx(() {
          final isLoading = controller.isActiveStatsLoading();
          return IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation), child: child),
                );
              },
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                      ),
                    )
                  : _showRefreshSuccess
                      ? Icon(
                          Icons.check_rounded,
                          key: const ValueKey('success'),
                          color: context.theme.colorScheme.primary,
                        )
                      : Icon(
                          Icons.refresh,
                          key: const ValueKey('refresh'),
                          color: context.theme.colorScheme.onSurface,
                        ),
            ),
            onPressed: isLoading ? null : _handleRefresh,
          );
        }),
      ],
      bodySlivers: [
        SliverToBoxAdapter(
          child: Obx(() => _buildBody()),
        ),
      ],
    );
  }
}
