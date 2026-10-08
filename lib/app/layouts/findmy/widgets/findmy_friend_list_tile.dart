import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_format.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_raw_data_dialog.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_selected_card.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';

class FindMyFriendListTile extends StatelessWidget {
  final FindMyFriend item;
  final FindMyController controller;
  final bool withLocation;

  const FindMyFriendListTile({super.key, required this.item, required this.controller, this.withLocation = true});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideContactInfo = shouldRedactFindMyContactInfo();
      final live = item.status == LocationStatus.live;
      final age = live ? 'Now' : (item.lastUpdated == null ? null : formatFindMyAge(item.lastUpdated!));
      final displayLocation = hideContactInfo
          ? "Location"
          : withLocation
          ? joinFindMyParts([item.shortAddress ?? "No location found", age])
          : (item.longAddress ?? "No location found");

      final handleState = item.handle != null ? HandleSvc.getOrCreateHandleState(item.handle!) : null;
      final displayName = hideContactInfo
          ? (handleState?.fakeName ?? 'Contact')
          : (item.handle?.displayName ?? item.title ?? "Unknown Friend");

      final hasLocation = item.latitude != null && item.longitude != null;
      final markerPoint = hasLocation ? controller.markerPointForFriend(item) : null;
      final markerKey = 'friend-${controller.markerIdentityForFriend(item)}';
      final selected = controller.isSelected(markerKey);
      final distance = hasLocation && withLocation
          ? controller.distanceLabelTo(LatLng(item.latitude!, item.longitude!))
          : null;

      final leading = Stack(
        clipBehavior: Clip.none,
        children: [
          ContactAvatarWidget(handle: item.handle),
          if (item.favoriteOrder != null)
            Positioned(
              right: -3,
              bottom: -2,
              child: Semantics(
                label: "Favorite",
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.theme.colorScheme.primary,
                    border: Border.all(color: context.theme.colorScheme.surface, width: 2),
                  ),
                  child: Icon(Icons.star, size: 11, color: context.theme.colorScheme.onPrimary),
                ),
              ),
            ),
        ],
      );

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
            ? FutureBuilder<ContactV2?>(
                future: hideContactInfo ? Future.value() : controller.nativeContactForFriend(item),
                builder: (context, snapshot) {
                  final contact = snapshot.data;
                  return FindMySelectedCard(
                    leading: leading,
                    title: displayName,
                    distance: distance,
                    street: hideContactInfo ? 'Location' : (item.longAddress ?? item.shortAddress ?? 'No location found'),
                    status: live ? 'Live' : age,
                    live: live,
                    onTap: markerPoint == null ? null : select,
                    onLongPress: hideContactInfo ? null : showRawData,
                    onDirections: withLocation && markerPoint != null
                        ? () => MapsLauncher.launchCoordinates(markerPoint.latitude, markerPoint.longitude)
                        : null,
                    onContact: contact == null
                        ? null
                        : () async {
                            try {
                              await MethodChannelSvc.actions.viewContactForm(nativeContactId: contact.nativeContactId);
                            } catch (e, s) {
                              Logger.error("Failed to find contact on device", error: e, trace: s);
                              showSnackbar("Error", "Failed to find contact on device!", type: SnackbarType.error);
                            }
                          },
                  );
                },
              )
            : ListTile(
                mouseCursor: MouseCursor.defer,
                leading: leading,
                title: Text(displayName),
                subtitle: Text(displayLocation),
                trailing: distance == null && !live && !item.locatingInProgress
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (live) const Icon(CupertinoIcons.largecircle_fill_circle, size: 16),
                          if (item.locatingInProgress) buildProgressIndicator(context),
                          if (distance != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              distance,
                              style: context.theme.textTheme.bodyMedium!.copyWith(
                                color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                onTap: withLocation && markerPoint != null ? select : null,
                onLongPress: hideContactInfo ? null : showRawData,
              ),
      );
    });
  }
}
