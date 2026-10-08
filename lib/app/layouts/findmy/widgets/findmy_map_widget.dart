import 'package:bluebubbles/app/layouts/findmy/findmy_camera.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_friend_sort.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_items_tab_view.dart';
import 'package:bluebubbles/app/wrappers/trackpad_bug_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class FindMyMapWidget extends StatelessWidget {
  final FindMyController controller;

  const FindMyMapWidget({super.key, required this.controller});

  /// Member marker keys of each group marker currently on the map.
  static final Map<String, List<String>> _groupMembers = {};

  @override
  Widget build(BuildContext context) {
    return TrackpadBugWrapper(
      builder: (context, bugDetected) {
        return Obx(() {
          final tab = controller.tabIndex.value;
          final products = switch (tab) {
            1 => findMyDeviceProducts(controller.devices),
            2 => findMyItemProducts(controller.devices),
            _ => const <FindMyDevice>[],
          };
          final productIds = products.map(controller.markerIdentityForDevice).toSet();
          final visibleMarkers = tab == 0
              ? controller.visibleMarkers
              : controller.visibleMarkers.where((marker) {
                  final key = _markerKey(marker);
                  return key.startsWith('device-') && productIds.contains(key.substring('device-'.length));
                }).toList();
          final currentLocation = controller.location.value;
          final currentCenter =
              tab == 0 && isUsableFindMyCoordinate(currentLocation?.latitude, currentLocation?.longitude)
              ? LatLng(currentLocation!.latitude, currentLocation.longitude)
              : null;
          LatLng? markerCenter;
          for (final marker in visibleMarkers) {
            if (isUsableFindMyCoordinate(marker.point.latitude, marker.point.longitude)) {
              markerCenter = marker.point;
              break;
            }
          }
          // Wait for GPS before falling back to a marker, so the map doesn't open elsewhere and then jump.
          final initialCenter = currentCenter ?? (controller.resolvingCurrentLocation.value ? null : markerCenter);

          if (initialCenter == null) {
            final isLoading =
                controller.resolvingCurrentLocation.value ||
                controller.fetching.value == true ||
                controller.fetching2.value == true;
            return Center(child: isLoading ? const CircularProgressIndicator() : const Text("Location unavailable"));
          }

          return FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialZoom: currentCenter != null ? 10.0 : 5.0,
              minZoom: 1.0,
              maxZoom: 18.0,
              initialCenter: initialCenter,
              onTap: (_, _) {
                controller.popupController.hideAllPopups();
                controller.clearSelection();
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) controller.noteCameraGesture();
              },
              keepAlive: true,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                forceOnlySinglePinchGesture: bugDetected,
              ),
              onMapReady: () {
                if (!controller.completer.isCompleted) {
                  controller.completer.complete();
                }
                controller.fitCameraToTab();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bluebubbles.app',
              ),
              Builder(
                builder: (context) {
                  final markerGroups = tab == 0
                      ? visibleMarkers.map((marker) => [marker]).toList()
                      : groupFindMyMarkersForZoom(visibleMarkers, MapCamera.of(context));
                  final renderedMarkers = markerGroups
                      .map((group) => group.length == 1 ? group.single : _buildGroupMarker(context, group))
                      .toList();
                  return PopupMarkerLayer(
                    options: PopupMarkerLayerOptions(
                      popupController: controller.popupController,
                      markers: renderedMarkers,
                      markerTapBehavior: MarkerTapBehavior.custom((popupSpec, _, _) {
                        _handleMarkerTap(popupSpec.marker);
                      }),
                    ),
                  );
                },
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
      },
    );
  }

  void _handleMarkerTap(Marker marker) {
    final key = _markerKey(marker);
    if (key.startsWith('group:')) {
      final members = _groupMembers[key.substring('group:'.length)] ?? const <String>[];
      final points = members
          .map((member) => controller.markers[member.replaceFirst('device-', '')]?.point)
          .whereType<LatLng>()
          .toList();
      if (points.isNotEmpty) controller.focusMarkerGroup(points);
      return;
    }
    if (key == 'current') return;
    controller.selectMarker(key, marker.point);
  }

  /// One zoom-dependent collision capsule: show up to two member icons,
  /// then `+N` for the additional products hidden at this zoom.
  Marker _buildGroupMarker(BuildContext context, List<Marker> group) {
    final memberKeys = group.map(_markerKey).toList();
    final groupKey = memberKeys.join('|');
    _groupMembers[groupKey] = memberKeys;
    final summary = summarizeFindMyGroup(memberKeys);
    final width = 8.0 + summary.visible.length * 27 + (summary.remaining > 0 ? 34 : 0);
    return Marker(
      key: ValueKey('group:$groupKey'),
      point: group.first.point,
      width: width,
      height: 35,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final key in summary.visible)
              SizedBox(width: 27, height: 27, child: Center(child: _buildProductGlyph(context, key))),
            if (summary.remaining > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${summary.remaining}',
                  style: context.theme.textTheme.labelMedium!.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGlyph(BuildContext context, String markerKey) {
    if (!markerKey.startsWith('device-')) return const Icon(Icons.devices, color: Colors.black, size: 22);
    final id = markerKey.substring('device-'.length);
    final item = controller.devices.firstWhereOrNull((device) => device.id == id);
    if (item == null) return const Icon(Icons.devices, color: Colors.black, size: 22);
    final isAirPods = item.isAppleAudioAccessory || (item.modelDisplayName?.toLowerCase().contains('airpods') ?? false);
    if (isAirPods) return const Icon(Icons.headphones, color: Colors.black, size: 22);
    final emoji = item.role?['emoji'] as String?;
    if (emoji != null) {
      return Text(emoji, style: context.theme.textTheme.titleMedium!.copyWith(fontFamily: 'Apple Color Emoji'));
    }
    return Icon(
      (item.isMac ?? false)
          ? Icons.computer
          : item.isConsideredAccessory
          ? Icons.headphones
          : Icons.phone_iphone,
      color: Colors.black,
      size: 22,
    );
  }

  static String _markerKey(Marker marker) => (marker.key as ValueKey?)?.value as String? ?? '';
}
