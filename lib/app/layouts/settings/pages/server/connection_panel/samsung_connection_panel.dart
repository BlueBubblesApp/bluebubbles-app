import 'package:bluebubbles/app/layouts/settings/pages/server/connection_panel/connection_panel_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SamsungConnectionPanel extends CustomStateful<ServerManagementPanelController> {
  const SamsungConnectionPanel({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungConnectionPanelState();
}

class _SamsungConnectionPanelState extends CustomState<SamsungConnectionPanel, void, ServerManagementPanelController>
    with ConnectionPanelHelpersMixin {
  IncrementalSyncManager? _manager;

  @override
  void initState() {
    super.initState();
    forceDelete = false;
  }

  Widget _buildStatusCard(StatusItemConfig item) {
    final value = resolveValue(controller, item.key);
    final color = resolveStatusColor(controller, item.key);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      color: tileColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.containerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.materialIcon, color: item.containerColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: context.theme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: context.theme.textTheme.bodySmall!.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusGrid() {
    // Each card is wrapped in its own Obx so only the affected card rebuilds
    // when a single observable changes. No LayoutBuilder needed — Row+Expanded
    // gives each card exactly half the available width without a layout pass.
    const items = ConnectionPanelHelpersMixin.kStatusItems;
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: Obx(() => _buildStatusCard(items[i]))),
          if (i + 1 < items.length) Expanded(child: Obx(() => _buildStatusCard(items[i + 1]))),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildInfoRow(InfoItemConfig item) {
    final value = resolveValue(controller, item.key);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      color: tileColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.containerColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.materialIcon, color: item.containerColor, size: 22),
        ),
        title: Text(item.label, style: context.theme.textTheme.bodyMedium),
        trailing: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.theme.textTheme.bodyMedium!.copyWith(
            color: context.theme.colorScheme.outline.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: item.onTap != null ? () => item.onTap!(context, controller) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrAction = buildQrCodeAction(context);
    return SettingsScaffold(
      title: "Server Management",
      initialHeader: null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      actions: [
        if (qrAction != null) qrAction,
      ],
      bodySlivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Text(
                  "Connection Status",
                  style: context.theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Center(child: _buildStatusGrid()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Server Info",
                        style: context.theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    Obx(() {
                      final isLoading = controller.hasCheckedStats.value == false;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                  ),
                                )
                              : Icon(Icons.refresh, color: context.theme.colorScheme.onSurface),
                          onPressed: isLoading ? null : () => controller.getServerStats(),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              ...ConnectionPanelHelpersMixin.kInfoItems.map((item) {
                return Obx(() => _buildInfoRow(item));
              }),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Text(
                  "Statistics & Analytics",
                  style: context.theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      buildViewStatsSection(context, controller, tileColor),
                    ],
                  )),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  "Connection & Sync",
                  style: context.theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                child: buildConnectionSyncSection(
                  context,
                  controller,
                  tileColor,
                  headerColor,
                  iosSubtitle,
                  materialSubtitle,
                  () => _manager,
                  (m) => _manager = m,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  "Server Actions",
                  style: context.theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                child: buildServerActionsSection(
                  context,
                  controller,
                  tileColor,
                  headerColor,
                  iosSubtitle,
                  materialSubtitle,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
