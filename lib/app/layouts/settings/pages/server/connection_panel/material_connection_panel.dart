import 'package:bluebubbles/app/layouts/settings/pages/server/connection_panel/connection_panel_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MaterialConnectionPanel extends CustomStateful<ServerManagementPanelController> {
  const MaterialConnectionPanel({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _MaterialConnectionPanelState();
}

class _MaterialConnectionPanelState extends CustomState<MaterialConnectionPanel, void, ServerManagementPanelController>
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
      elevation: 1,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: tileColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.containerColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.materialIcon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
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
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: tileColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.containerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.materialIcon, color: Colors.white, size: 20),
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
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 4),
                child: Text("Connection Status", style: materialSubtitle),
              ),
              Center(child: _buildStatusGrid()),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 0, 4),
                child: Row(
                  children: [
                    Expanded(child: Text("Server Info", style: materialSubtitle)),
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
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
                child: Text("Statistics & Analytics", style: materialSubtitle),
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  buildViewStatsSection(context, controller, tileColor),
                ],
              ),
              buildConnectionSyncSection(
                context,
                controller,
                tileColor,
                headerColor,
                iosSubtitle,
                materialSubtitle,
                () => _manager,
                (m) => _manager = m,
              ),
              buildServerActionsSection(
                context,
                controller,
                tileColor,
                headerColor,
                iosSubtitle,
                materialSubtitle,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}
