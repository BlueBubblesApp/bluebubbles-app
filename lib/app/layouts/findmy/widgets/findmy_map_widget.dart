import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
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
  final bool interactive;
  final MapController? mapController;
  final VoidCallback? onMapReady;
  final double? initialZoom;

  const FindMyMapWidget({
    super.key,
    required this.controller,
    this.interactive = true,
    this.mapController,
    this.onMapReady,
    this.initialZoom,
  });

  LatLng _initialCenter() {
    if (controller.location.value != null) {
      return LatLng(controller.location.value!.latitude, controller.location.value!.longitude);
    }
    final participants = controller.participantFriendsWithLocation;
    if (participants.isNotEmpty) {
      return LatLng(participants.first.latitude!, participants.first.longitude!);
    }
    return const LatLng(0, 0);
  }

  double _initialZoom() {
    if (initialZoom != null) return initialZoom!;
    if (controller.isParticipantMode) return 13;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final activeMapController = mapController ?? controller.mapController;
    final content = TrackpadBugWrapper(builder: (context, bugDetected) {
      return Obx(() => FlutterMap(
            key: ValueKey(activeMapController),
            mapController: activeMapController,
            options: MapOptions(
              initialZoom: _initialZoom(),
              minZoom: 1.0,
              maxZoom: 18.0,
              initialCenter: _initialCenter(),
              onTap: (_, __) => controller.popupController.hideAllPopups(),
              keepAlive: mapController == null,
              interactionOptions: InteractionOptions(
                flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
                forceOnlySinglePinchGesture: bugDetected,
              ),
              onMapReady: () {
                if (mapController == null && !controller.completer.isCompleted) {
                  controller.completer.complete();
                }
                onMapReady?.call();
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
          ));
    });

    if (!interactive) return IgnorePointer(child: content);
    return content;
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
      final markerKey = keyStr.substring("friend-".length);
      final item = controller.friends.firstWhereOrNull(
        (e) => controller.friendMarkerKeyFor(e) == markerKey || e.stableId == markerKey,
      );
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
              Text(hideContactInfo ? "Device" : (item.name ?? "Unknown Device"),
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
