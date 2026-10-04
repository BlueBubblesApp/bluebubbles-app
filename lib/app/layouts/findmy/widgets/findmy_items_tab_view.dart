import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_device_list_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FindMyItemsTabView extends StatelessWidget {
  final FindMyController controller;

  const FindMyItemsTabView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final allItems = controller.devices.where((item) => item.isConsideredAccessory).toList();

      // Apple reports some accessories as a component of a parent accessory: an
      // AirPods Max earpiece arrives as its own entry named "single" carrying
      // the headphones' groupName. Find My shows one row per accessory, so drop
      // components whose parent is already listed.
      final parentNames =
          allItems.where((item) => !item.isGroupedComponent).map((item) => item.name).whereType<String>().toSet();
      final items =
          allItems.where((item) => !(item.isGroupedComponent && parentNames.contains(item.groupName))).toList();

      final itemsWithLocation =
          items.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) != null).toList();
      final itemsWithoutLocation =
          items.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) == null).toList();

      return SliverList(
        delegate: SliverChildListDelegate([
          if (controller.fetching.value == null ||
              controller.fetching.value == true ||
              (controller.fetching.value == false && allItems.isEmpty))
            _buildEmptyState(context),
          if (itemsWithLocation.isNotEmpty)
            SettingsHeader(
              iosSubtitle: context.theme.textTheme.labelLarge!.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w300,
              ),
              materialSubtitle: context.theme.textTheme.labelLarge!.copyWith(
                color: context.theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              text: "Items",
            ),
          if (itemsWithLocation.isNotEmpty)
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
                      item: itemsWithLocation[i],
                      controller: controller,
                      isItem: true,
                    ),
                    itemCount: itemsWithLocation.length,
                  ),
                ),
              ],
            ),
          if (itemsWithoutLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: context.tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.transparent)),
                    title: const Text("Items without locations"),
                    initiallyExpanded: true,
                    children: itemsWithoutLocation
                        .map((item) => FindMyDeviceListTile(
                              item: item,
                              controller: controller,
                              isItem: true,
                            ))
                        .toList(),
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
                        ? "You have no accessories."
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
