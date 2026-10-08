import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_format.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_friend_sort.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_raw_data_dialog.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_selected_card.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';

class FindMyDeviceListTile extends StatelessWidget {
  final FindMyDevice item;
  final FindMyController controller;
  final bool isItem;

  const FindMyDeviceListTile({super.key, required this.item, required this.controller, this.isItem = false});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideContactInfo = shouldRedactFindMyContactInfo();

      final displayName = hideContactInfo
          ? (isItem ? "Item" : "Device")
          : (item.displayName ?? (isItem ? "Unknown Item" : "Unknown Device"));

      final hasUsableCoordinates = isUsableFindMyCoordinate(item.location?.latitude, item.location?.longitude);
      final displayLocation = hideContactInfo
          ? "Location"
          : (item.address?.label ??
                item.address?.mapItemFullAddress ??
                (hasUsableCoordinates ? "Locating…" : "No location found"));
      final timeStamp = item.location?.timeStamp;
      final foundAt = item.lastKnownLocationAt ??
          (timeStamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timeStamp));
      final age = foundAt == null ? null : formatFindMyAge(foundAt);
      final subtitle = hideContactInfo ? displayLocation : joinFindMyParts([displayLocation, age]);
      final fullAddress = item.address?.mapItemFullAddress?.trim();
      final hasFullAddress = fullAddress?.isNotEmpty ?? false;
      final markerPoint = hasUsableCoordinates ? controller.markerPointForDevice(item) : null;
      final canOpenMaps = markerPoint != null || hasFullAddress;
      final markerKey = 'device-${controller.markerIdentityForDevice(item)}';
      final selected = controller.isSelected(markerKey);
      final distance = hasUsableCoordinates
          ? controller.distanceLabelTo(LatLng(item.location!.latitude!, item.location!.longitude!))
          : null;

      Future<void> select() async {
        await controller.completer.future;
        await controller.selectMarker(markerKey, markerPoint!);
      }

      void showRawData() => showDialog(
        context: context,
        builder: (context) => FindMyRawDataDialog(item: item),
      );

      return AnimatedSize(
        key: controller.rowKeyFor(markerKey),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: selected
            ? FindMySelectedCard(
                title: displayName,
                distance: distance,
                street: hideContactInfo ? 'Location' : (hasFullAddress ? fullAddress : displayLocation),
                status: age,
                onTap: markerPoint == null ? null : select,
                onLongPress: hideContactInfo ? null : showRawData,
                onDirections: canOpenMaps
                    ? () async {
                        if (markerPoint != null) {
                          await MapsLauncher.launchCoordinates(markerPoint.latitude, markerPoint.longitude);
                        } else {
                          await MapsLauncher.launchQuery(fullAddress!);
                        }
                      }
                    : null,
              )
            : ListTile(
                mouseCursor: MouseCursor.defer,
                title: Text(displayName),
                subtitle: Text(subtitle),
                trailing: distance == null
                    ? null
                    : Text(
                        distance,
                        style: context.theme.textTheme.bodyMedium!.copyWith(
                          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                onTap: markerPoint != null ? select : null,
                onLongPress: hideContactInfo ? null : showRawData,
              ),
      );
    });
  }
}
