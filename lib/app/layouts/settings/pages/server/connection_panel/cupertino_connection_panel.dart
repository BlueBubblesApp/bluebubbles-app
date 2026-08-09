import 'package:bluebubbles/app/layouts/settings/pages/server/connection_panel/connection_panel_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoConnectionPanel extends CustomStateful<ServerManagementPanelController> {
  const CupertinoConnectionPanel({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoConnectionPanelState();
}

class _CupertinoConnectionPanelState
    extends CustomState<CupertinoConnectionPanel, void, ServerManagementPanelController>
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
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.containerColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.iosIcon, color: Colors.white, size: 18),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _buildInfoRow(InfoItemConfig item) {
    final value = resolveValue(controller, item.key);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsTile(
          backgroundColor: tileColor,
          leading: SettingsLeadingIcon(
            iosIcon: item.iosIcon,
            materialIcon: item.materialIcon,
            containerColor: item.containerColor,
          ),
          title: item.label,
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
        if (item != ConnectionPanelHelpersMixin.kInfoItems.last) const SettingsDivider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrAction = buildQrCodeAction(context);
    return SettingsScaffold(
      title: "Server Management",
      initialHeader: "Connection Details",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      actions: [
        ?qrAction,
      ],
      bodySlivers: [
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusGrid(),
              Container(
                height: 60,
                color: Colors.transparent,
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 30, right: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: Text("Server Info", style: iosSubtitle)),
                      Obx(() {
                        final isLoading = controller.hasCheckedStats.value == false;
                        return CupertinoButton(
                          padding: const EdgeInsets.only(right: 16.0),
                          minSize: 28,
                          onPressed: isLoading ? null : () => controller.getServerStats(),
                          child: isLoading
                              ? const CupertinoActivityIndicator()
                              : const Icon(CupertinoIcons.refresh, size: 18),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: ConnectionPanelHelpersMixin.kInfoItems.map((item) {
                  return Obx(() => _buildInfoRow(item));
                }).toList(),
              ),
              SettingsHeader(
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Statistics & Analytics",
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
