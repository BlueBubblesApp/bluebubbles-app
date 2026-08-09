import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_raw_data_dialog.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maps_launcher/maps_launcher.dart';

class FindMyFriendListTile extends StatelessWidget {
  final FindMyFriend item;
  final FindMyController controller;
  final bool withLocation;

  const FindMyFriendListTile({
    super.key,
    required this.item,
    required this.controller,
    this.withLocation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideContactInfo = shouldRedactFindMyContactInfo();
      final lastUpdatedSuffix = item.lastUpdated == null || item.status == LocationStatus.live
          ? ""
          : "\nLast updated ${buildDate(item.lastUpdated)}";
      final displayLocation = hideContactInfo
          ? (withLocation ? "Location$lastUpdatedSuffix" : "Location")
          : withLocation
              ? ("${item.shortAddress ?? "No location found"}$lastUpdatedSuffix")
              : (item.longAddress ?? "No location found");

      final handleState = item.handle != null ? HandleSvc.getOrCreateHandleState(item.handle!) : null;
      final displayName = hideContactInfo
          ? (handleState?.fakeName ?? 'Contact')
          : (item.handle?.displayName ?? item.title ?? "Unknown Friend");

      final hasLocation = item.latitude != null && item.longitude != null;
      final markerPoint = hasLocation ? controller.markerPointForFriend(item) : null;

      return ListTile(
        mouseCursor: MouseCursor.defer,
        leading: ContactAvatarWidget(handle: item.handle),
        title: Text(displayName),
        subtitle: Text(displayLocation),
        trailing: withLocation && hasLocation
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.status == LocationStatus.live) const Icon(CupertinoIcons.largecircle_fill_circle),
                  if (item.locatingInProgress) buildProgressIndicator(context),
                  ButtonTheme(
                    minWidth: 1,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: context.theme.colorScheme.primaryContainer,
                      ),
                      onPressed: () async {
                        if (markerPoint == null) return;
                        await MapsLauncher.launchCoordinates(markerPoint.latitude, markerPoint.longitude);
                      },
                      child: const Icon(Icons.directions, size: 20),
                    ),
                  ),
                ],
              )
            : null,
        onTap: withLocation && markerPoint != null
            ? () async {
                if (context.isPhone) {
                  await controller.panelController.close();
                }
                await controller.completer.future;
                final marker = controller.markers[item.stableId];
                if (marker == null) return;
                controller.popupController.showPopupsOnlyFor([marker]);
                controller.mapController.move(markerPoint, 10);
              }
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
