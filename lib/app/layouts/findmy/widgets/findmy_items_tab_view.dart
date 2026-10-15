import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_friend_sort.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_device_list_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

bool _hasDisplayLocation(FindMyDevice item) {
  final label = item.address?.label?.trim();
  final address = item.address?.mapItemFullAddress?.trim();
  return (label?.isNotEmpty ?? false) || (address?.isNotEmpty ?? false);
}

const _audioPartRoles = {'left', 'right', 'case', 'single'};

String? _audioPartRole(FindMyDevice item) {
  final role = item.name?.trim().toLowerCase();
  final isHawkeye = item.deviceModel == 'hawkeye' || item.deviceClass == 'hawkeye';
  return item.isAppleAudioAccessory && isHawkeye && _audioPartRoles.contains(role) ? role : null;
}

String? _componentGroupId(FindMyDevice item) {
  if (_audioPartRole(item) == null || !(item.groupName?.trim().isNotEmpty ?? false)) return null;
  final id = item.groupIdentifier?.trim();
  return (id?.isNotEmpty ?? false) ? id : null;
}

int _locationQuality(FindMyDevice item) {
  if (_hasDisplayLocation(item)) return 2;
  if (isUsableFindMyCoordinate(item.location?.latitude, item.location?.longitude)) return 1;
  return 0;
}

FindMyDevice _bestLocatedComponent(Iterable<FindMyDevice> components) {
  return components.reduce((best, candidate) {
    final quality = _locationQuality(candidate).compareTo(_locationQuality(best));
    if (quality != 0) return quality > 0 ? candidate : best;
    return (candidate.location?.timeStamp ?? 0) > (best.location?.timeStamp ?? 0) ? candidate : best;
  });
}

String? _serialSuffix(FindMyDevice item) {
  final serial = item.serialNumber?.trim();
  return serial != null && serial.length >= 4 ? serial.substring(serial.length - 4) : null;
}

/// Presents one top-level row per Apple audio-accessory group. Weak orphan
/// records are hidden only when they uniquely match a current grouped part;
/// ambiguous records remain visible rather than losing locator data.
List<FindMyDevice> collapseFindMyAccessoryComponents(List<FindMyDevice> items) {
  final componentsByGroup = <String, List<FindMyDevice>>{};
  for (final item in items) {
    final groupId = _componentGroupId(item);
    if (groupId != null) componentsByGroup.putIfAbsent(groupId, () => []).add(item);
  }

  final groupsByName = <String, List<String>>{};
  for (final entry in componentsByGroup.entries) {
    final name = entry.value.first.groupName!.trim().toLowerCase();
    groupsByName.putIfAbsent(name, () => []).add(entry.key);
  }
  final parentsByName = <String, List<FindMyDevice>>{};
  for (final item in items.where((item) => _audioPartRole(item) == null && item.deviceClass == 'Accessory')) {
    final name = item.name?.trim().toLowerCase();
    if (name?.isNotEmpty ?? false) parentsByName.putIfAbsent(name!, () => []).add(item);
  }
  final groupsBackedByUniqueParents = <String>{};
  for (final entry in groupsByName.entries) {
    if (entry.value.length == 1 && parentsByName[entry.key]?.length == 1) {
      groupsBackedByUniqueParents.add(entry.value.single);
    }
  }

  final activeComponents = componentsByGroup.values.expand((components) => components).toList();
  final emittedGroups = <String>{};
  final output = <FindMyDevice>[];
  for (final item in items) {
    final groupId = _componentGroupId(item);
    if (groupId != null) {
      if (groupsBackedByUniqueParents.contains(groupId) || !emittedGroups.add(groupId)) continue;
      output.add(_bestLocatedComponent(componentsByGroup[groupId]!));
      continue;
    }

    final role = _audioPartRole(item);
    final suffix = _serialSuffix(item);
    final product = item.productIdentifier?.trim();
    final isWeakOrphan =
        role != null &&
        (item.groupIdentifier?.isNotEmpty ?? false) &&
        !(item.groupName?.isNotEmpty ?? false) &&
        _locationQuality(item) == 0 &&
        suffix != null &&
        (product?.isNotEmpty ?? false);
    if (isWeakOrphan) {
      final matches = activeComponents.where(
        (candidate) =>
            _audioPartRole(candidate) == role &&
            candidate.productIdentifier?.trim() == product &&
            _serialSuffix(candidate) == suffix,
      );
      if (matches.length == 1) continue;
    }

    output.add(item);
  }
  return output;
}

bool isFindMyAudioProduct(FindMyDevice item) {
  if (item.isAppleAudioAccessory) return true;
  final identity = [
    item.modelDisplayName,
    item.deviceDisplayName,
    item.deviceModel,
    item.name,
  ].whereType<String>().join(' ').toLowerCase();
  return identity.contains('airpods');
}

/// Logical products Apple presents under Devices. AirPods component records
/// are collapsed first, then moved here rather than being treated as Items.
List<FindMyDevice> findMyDeviceProducts(List<FindMyDevice> all) {
  final ordinaryDevices = all.where((item) => !item.isConsideredAccessory);
  final accessories = collapseFindMyAccessoryComponents(all.where((item) => item.isConsideredAccessory).toList());
  return [...ordinaryDevices, ...accessories.where(isFindMyAudioProduct)];
}

/// Logical Find My network items (AirTags, wallets, luggage and compatible
/// third-party trackers), excluding AirPods.
List<FindMyDevice> findMyItemProducts(List<FindMyDevice> all) => collapseFindMyAccessoryComponents(
  all.where((item) => item.isConsideredAccessory).toList(),
).where((item) => !isFindMyAudioProduct(item)).toList();

class FindMyItemsTabView extends StatelessWidget {
  final FindMyController controller;

  const FindMyItemsTabView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = findMyItemProducts(controller.devices);
      final allItems = items;
      final itemsWithLocation = items.where(_hasDisplayLocation).toList();
      final itemsWithoutLocation = items.where((item) => !_hasDisplayLocation(item)).toList();

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
              (controller.fetching.value == false && allItems.isEmpty))
            _buildEmptyState(context),
          if (itemsWithLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Items"),
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
                    itemBuilder: (context, i) =>
                        FindMyDeviceListTile(item: itemsWithLocation[i], controller: controller, isItem: true),
                    itemCount: itemsWithLocation.length,
                  ),
                ),
              ],
            ),
          if (itemsWithoutLocation.isNotEmpty)
            SettingsHeader(
              iosSubtitle: iosSubtitle,
              materialSubtitle: materialSubtitle,
              text: "Items without locations",
            ),
          if (itemsWithoutLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: context.tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, i) =>
                        FindMyDeviceListTile(item: itemsWithoutLocation[i], controller: controller, isItem: true),
                    itemCount: itemsWithoutLocation.length,
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
