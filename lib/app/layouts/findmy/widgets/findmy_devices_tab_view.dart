import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_device_list_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FindMyDevicesTabView extends StatelessWidget {
  final FindMyController controller;

  const FindMyDevicesTabView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final allDevices = controller.devices.where((item) => !item.isConsideredAccessory).toList();

      final devicesWithLocation =
          allDevices.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) != null).toList();

      final devicesWithoutLocation =
          allDevices.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) == null).toList();

      final iosSubtitle = context.theme.textTheme.labelLarge!.copyWith(
        color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w300,
      );
      final materialSubtitle = context.theme.textTheme.labelLarge!.copyWith(
        color: context.theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      );

      return SliverList(
        delegate: SliverChildListDelegate([
          if (controller.fetching.value == null ||
              controller.fetching.value == true ||
              (controller.fetching.value == false && allDevices.isEmpty))
            _buildEmptyState(context),
          if (devicesWithLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Devices"),
          if (devicesWithLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: context.tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, i) => FindMyDeviceListTile(
                      item: devicesWithLocation[i],
                      controller: controller,
                    ),
                    itemCount: devicesWithLocation.length,
                  ),
                ),
              ],
            ),
          if (devicesWithoutLocation.isNotEmpty)
            SettingsHeader(
                iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Devices without locations"),
          if (devicesWithoutLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: context.tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, i) => FindMyDeviceListTile(
                      item: devicesWithoutLocation[i],
                      controller: controller,
                    ),
                    itemCount: devicesWithoutLocation.length,
                  ),
                ),
              ],
            ),
        ]),
      );
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                controller.fetching.value == null
                    ? "Something went wrong!"
                    : controller.fetching.value == false
                        ? "You have no devices."
                        : "Getting FindMy data...",
                style: context.theme.textTheme.labelLarge,
              ),
            ),
            if (controller.fetching.value == true) buildProgressIndicator(context, size: 15),
          ],
        ),
      ),
    );
  }
}
