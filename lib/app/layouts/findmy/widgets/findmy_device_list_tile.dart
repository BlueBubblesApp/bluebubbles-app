import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_raw_data_dialog.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maps_launcher/maps_launcher.dart';

class FindMyDeviceListTile extends StatelessWidget {
  final FindMyDevice item;
  final FindMyController controller;
  final bool isItem;

  const FindMyDeviceListTile({
    super.key,
    required this.item,
    required this.controller,
    this.isItem = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideContactInfo = shouldRedactFindMyContactInfo();

      final displayName =
          hideContactInfo ? (isItem ? "Item" : "Device") : (item.name ?? (isItem ? "Unknown Item" : "Unknown Device"));

      final displayLocation = hideContactInfo
          ? "Location"
          : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found");

      final hasLocation = item.location?.latitude != null && item.location?.longitude != null;
      final markerPoint = hasLocation ? controller.markerPointForDevice(item) : null;

      return ListTile(
        mouseCursor: MouseCursor.defer,
        title: Text(displayName),
        subtitle: Text(displayLocation),
        onTap: markerPoint != null
            ? () async {
                await controller.panelController.close();
                await controller.completer.future;
                final marker = controller.markers[item.id];
                if (marker == null) return;
                controller.popupController.showPopupsOnlyFor([marker]);
                controller.mapController.move(markerPoint, 10);
              }
            : null,
        trailing: markerPoint != null
            ? ButtonTheme(
                minWidth: 1,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: context.theme.colorScheme.primaryContainer,
                  ),
                  onPressed: () async {
                    await MapsLauncher.launchCoordinates(markerPoint.latitude, markerPoint.longitude);
                  },
                  child: const Icon(Icons.directions, size: 20),
                ),
              )
            : null,
        onLongPress: hideContactInfo
            ? null
            : () async {
                showDialog(
                  context: context,
                  builder: (context) => FindMyRawDataDialog(item: item),
                );
              },
      );
    });
  }
}
