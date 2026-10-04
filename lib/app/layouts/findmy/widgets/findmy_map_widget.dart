import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_friend_sort.dart';
import 'package:bluebubbles/app/wrappers/trackpad_bug_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class FindMyMapWidget extends StatelessWidget {
  final FindMyController controller;

  const FindMyMapWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TrackpadBugWrapper(builder: (context, bugDetected) {
      return Obx(() {
        final currentLocation = controller.location.value;
        final currentCenter = isUsableFindMyCoordinate(currentLocation?.latitude, currentLocation?.longitude)
            ? LatLng(currentLocation!.latitude, currentLocation.longitude)
            : null;
        LatLng? markerCenter;
        for (final marker in controller.markers.values) {
          if (isUsableFindMyCoordinate(marker.point.latitude, marker.point.longitude)) {
            markerCenter = marker.point;
            break;
          }
        }
        // Wait for GPS before falling back to a marker, so the map doesn't open elsewhere and then jump.
        final initialCenter = currentCenter ?? (controller.resolvingCurrentLocation.value ? null : markerCenter);

        if (initialCenter == null) {
          final isLoading = controller.resolvingCurrentLocation.value ||
              controller.fetching.value == true ||
              controller.fetching2.value == true;
          return Center(
            child: isLoading ? const CircularProgressIndicator() : const Text("Location unavailable"),
          );
        }

        return FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialZoom: currentCenter != null ? 10.0 : 5.0,
              minZoom: 1.0,
              maxZoom: 18.0,
              initialCenter: initialCenter,
              onTap: (_, _) => controller.popupController.hideAllPopups(),
              keepAlive: true,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                forceOnlySinglePinchGesture: bugDetected,
              ),
              onMapReady: () {
                if (!controller.completer.isCompleted) {
                  controller.completer.complete();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bluebubbles.app',
              ),
              PopupMarkerLayer(
                options: PopupMarkerLayerOptions(
                  popupController: controller.popupController,
                  markers: controller.markers.values.toList(),
                  popupDisplayOptions: PopupDisplayOptions(
                    builder: (context, marker) => _buildMarkerPopup(context, marker),
                  ),
                ),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          );
      });
    });
  }

  Widget _buildMarkerPopup(BuildContext context, Marker marker) {
    final ValueKey? key = marker.key as ValueKey?;
    final keyStr = key?.value as String? ?? '';
    if (keyStr == "current") return const SizedBox();

    if (keyStr.startsWith("device-")) {
      final deviceId = keyStr.substring("device-".length);
      final item = controller.devices.firstWhereOrNull((e) => (e.id ?? '') == deviceId);
      if (item == null) return const SizedBox();
      return _buildDevicePopup(context, item);
    } else if (keyStr.startsWith("friend-")) {
      final stableId = keyStr.substring("friend-".length);
      final item = controller.friends.firstWhereOrNull((e) => e.stableId == stableId);
      if (item == null) return const SizedBox();
      return _buildFriendPopup(context, item);
    }

    return const SizedBox();
  }

  Widget _buildDevicePopup(BuildContext context, FindMyDevice item) {
    return Obx(() {
      final hideContactInfo = shouldRedactFindMyContactInfo();
      return Padding(
        padding: const EdgeInsets.only(bottom: 5.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hideContactInfo ? "Device" : (item.displayName ?? "Unknown Device"),
                  style: context.theme.textTheme.labelLarge),
              Text(
                  hideContactInfo
                      ? "Location"
                      : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found"),
                  style: context.theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFriendPopup(BuildContext context, FindMyFriend item) {
    return Obx(() {
      final hideContactInfo = shouldRedactFindMyContactInfo();
      final handleState = item.handle != null ? HandleSvc.getOrCreateHandleState(item.handle!) : null;
      final displayName = hideContactInfo
          ? (handleState?.fakeName ?? 'Contact')
          : (item.handle?.displayName ?? item.title ?? "Unknown Friend");

      return Padding(
        padding: const EdgeInsets.only(bottom: 5.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: context.theme.textTheme.labelLarge),
              Text(hideContactInfo ? "Location" : (item.longAddress ?? "No location found"),
                  style: context.theme.textTheme.bodySmall),
              if (item.lastUpdated != null && item.status != LocationStatus.live)
                Text("Last updated ${buildDate(item.lastUpdated)}", style: context.theme.textTheme.bodySmall),
              if (item.status != null)
                Text("${item.status!.name.capitalize!} Location", style: context.theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    });
  }
}
