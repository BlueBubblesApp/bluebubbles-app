import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_location_clipper.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_handle_matcher.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_participant_prefetch.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';

class FindMyController extends GetxController {
  FindMyController({this.participantFilter, this.showSelf = false});

  /// When set, only friends matching these chat participants are shown (conversation details mode).
  List<Handle>? participantFilter;

  /// Conversation-details card/sheet only: also show the user's own GPS marker.
  /// The main Find My page ignores this and tracks self via [!isParticipantMode].
  final bool showSelf;

  bool get isParticipantMode => participantFilter != null;

  static const String _kCurrentMarkerKey = 'current';

  List<FindMyFriend> get participantFriendsWithLocation =>
      friendsWithLocation.where((f) => matchesParticipantFilter(f)).toList();

  // Scroll Controllers
  final ScrollController devicesController = ScrollController();
  final ScrollController itemsController = ScrollController();
  final ScrollController friendsController = ScrollController();

  // Map & Panel Controllers
  final PopupController popupController = PopupController();
  final MapController mapController = MapController();
  final PanelController panelController = PanelController();
  final completer = Completer<void>();

  // Tab Controller (needs to be created with vsync in the widget)
  TabController? tabController;

  // Observable state variables
  final RxInt tabIndex = 0.obs;
  final RxList<FindMyDevice> devices = <FindMyDevice>[].obs;
  final RxList<FindMyFriend> friends = <FindMyFriend>[].obs;
  final RxList<FindMyFriend> friendsWithLocation = <FindMyFriend>[].obs;
  final RxList<FindMyFriend> friendsWithoutLocation = <FindMyFriend>[].obs;
  final RxMap<String, Marker> markers = <String, Marker>{}.obs;
  final Rxn<Position> location = Rxn<Position>();
  final Rxn<bool> fetching = Rxn<bool>(true);
  final RxBool refreshing = false.obs;
  final Rxn<bool> fetching2 = Rxn<bool>(true);
  final RxBool refreshing2 = false.obs;
  final RxBool canRefresh = false.obs;
  final RxBool hasMovedToCurrentLocation = false.obs;

  StreamSubscription? locationSub;
  Timer? _refreshTimer;
  StreamSubscription? _redactedModeListener;
  StreamSubscription? _hideContactInfoListener;
  StreamSubscription? _findMyLocationListener;

  @override
  void onInit() {
    super.onInit();
    if (isParticipantMode) {
      // Seed from the session snapshot so the details card can paint the real
      // map on first frame when we already know participants are sharing.
      _hydrateFromPrefetchSnapshot();
      _loadParticipantLocations();
    } else {
      getLocations();
    }

    // Listen via the event dispatcher rather than the socket itself — the socket is
    // torn down and rebuilt on every restart (backgrounding, a server URL refresh),
    // and a listener bound to the old instance would just stop receiving updates.
    _findMyLocationListener = EventDispatcherSvc.stream.listen((event) {
      if (event.type == 'new-findmy-location') _handleNewFindMyLocation(event.data);
    });

    if (!isParticipantMode) {
      _scheduleRefreshGate();
    }
    _setupRedactionListeners();
  }

  /// Applies the shared prefetch friends list synchronously so
  /// [participantFriendsWithLocation] is non-empty before the first Obx build
  /// when the snapshot already has matching sharers.
  void _hydrateFromPrefetchSnapshot() {
    final snapshot = FindMyParticipantPrefetch.sessionFriends;
    if (snapshot.isEmpty) return;

    friends.value = List<FindMyFriend>.from(snapshot);
    friendsWithLocation.value =
        friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
    friendsWithoutLocation.value =
        friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

    if (participantFriendsWithLocation.isEmpty) return;

    _rebuildParticipantMarkers();
    fetching2.value = false;
  }

  Future<void> _loadParticipantLocations() async {
    await getLocations(refreshFriends: false, suppressErrors: true);
    if (!_isAlive) return;
    if (participantFriendsWithLocation.isEmpty && FindMyParticipantPrefetch.canPostParticipantRefresh) {
      FindMyParticipantPrefetch.recordParticipantRefresh();
      await getLocations(refreshFriends: true, suppressErrors: true);
    }
  }

  bool matchesParticipantFilter(FindMyFriend friend) {
    if (participantFilter == null) return true;
    return FindMyHandleMatcher.matchesAny(friend, participantFilter!);
  }

  void updateParticipantFilter(List<Handle> handles) {
    participantFilter = handles;
    _rebuildParticipantMarkers();
  }

  /// True once the card's [mapController] has attached to a [FlutterMap].
  bool _participantMapReady = false;
  bool _ownLocationStarted = false;
  bool _pendingOwnLocationFit = false;

  /// Expanded-sheet map, if open. Fitted alongside the card when own GPS arrives.
  MapController? participantSheetMapController;

  static bool _isSameFindMyFriend(FindMyFriend a, FindMyFriend b) =>
      FindMyHandleMatcher.friendIdentifiersMatch(a, b);

  String _friendMarkerKey(FindMyFriend friend) {
    final primary = friend.stableId ?? friend.handleAddress ?? friend.title;
    if (primary != null) return primary;

    final segments = <String>{
      ...FindMyHandleMatcher.friendIdentifiers(friend),
      if (friend.latitude != null && friend.longitude != null) '${friend.latitude},${friend.longitude}',
      if (friend.subtitle != null) friend.subtitle!,
      if (friend.longAddress != null) friend.longAddress!,
      if (friend.lastUpdated != null) friend.lastUpdated!.millisecondsSinceEpoch.toString(),
    }..removeWhere((s) => s.isEmpty);

    if (segments.isEmpty) {
      return 'friend-unknown-${Object.hash(friend.latitude, friend.longitude, friend.longAddress, friend.subtitle)}';
    }

    final sorted = segments.toList()..sort();
    return sorted.join('|');
  }

  bool get _isAlive => !isClosed;

  void _rebuildParticipantMarkers() {
    if (!isParticipantMode) return;
    final allowedKeys = participantFriendsWithLocation.map(_friendMarkerKey).toSet();
    markers.removeWhere((key, _) => !_keepParticipantMarker(key, allowedKeys));
    for (final friend in participantFriendsWithLocation) {
      buildFriendMarker(friend);
    }
  }

  bool _keepParticipantMarker(String key, Set<String> allowedKeys) {
    if (allowedKeys.contains(key)) return true;
    return showSelf && key == _kCurrentMarkerKey;
  }

  /// Card map finished attaching — later location updates may fit the camera.
  /// First framing uses [FindMyMapWidget] initialCenter / initialCameraFit so a
  /// group [MapController.move] does not race the first tile request.
  void onParticipantMapReady() {
    _participantMapReady = true;
    if (!_pendingOwnLocationFit) return;
    _pendingOwnLocationFit = false;
    fitMapToParticipantMarkers();
  }

  /// Pixel inset when framing 2+ pins on the full-page sheet.
  static const EdgeInsets _kSheetFitPadding = EdgeInsets.all(40);

  /// Extra inset for the compact details card. Horizontal is larger because
  /// longitude-extreme pins (e.g. Australia, Central America) sit on the clipped
  /// left/right edges; vertical stays smaller so the 2.2 aspect preview still fits.
  static const EdgeInsets _kCardFitPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 16);

  /// Bounds fit for 2+ spread-out pins. Null for a single pin or stacked pins
  /// (use center/zoom 13) — a zero-size CameraFit produces LatLng(NaN,NaN).
  ///
  /// [compact] uses [_kCardFitPadding] for the details-card preview.
  CameraFit? participantMarkersCameraFit({bool compact = false}) {
    final points = _participantCameraPoints(includeSelf: !compact);
    if (!_canCameraFit(points)) return null;
    return CameraFit.coordinates(
      coordinates: points,
      padding: compact ? _kCardFitPadding : _kSheetFitPadding,
      maxZoom: 13,
    );
  }

  List<LatLng> _participantCameraPoints({bool includeSelf = true}) {
    final points = participantFriendsWithLocation
        .map(markerPointForFriend)
        .where(isFiniteLatLng)
        .toList();
    if (!includeSelf || !showSelf) return points;
    final own = markers[_kCurrentMarkerKey]?.point;
    if (own != null && isFiniteLatLng(own)) points.add(own);
    return points;
  }

  /// False when CameraFit.coordinates would divide by zero / emit NaN zoom.
  static bool _canCameraFit(List<LatLng> points) {
    if (points.length < 2) return false;
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    // ~11m. Stacked/identical pins must not go through CameraFit.
    const epsilon = 1e-4;
    return (maxLat - minLat) > epsilon || (maxLng - minLng) > epsilon;
  }

  /// Fits [target], or the card (and open sheet) when omitted.
  void fitMapToParticipantMarkers({MapController? target}) {
    if (target != null) {
      _fitParticipantCamera(target, compact: false);
      return;
    }
    if (isParticipantMode && !_participantMapReady) return;

    _fitParticipantCamera(mapController, compact: true);
    final sheet = participantSheetMapController;
    if (sheet != null) _fitParticipantCamera(sheet, compact: false);
  }

  void _fitParticipantCamera(MapController map, {required bool compact}) {
    if (!_mapHasLayoutSize(map)) return;

    // Use markerPointForFriend so redacted mode centers on decoy pins, not real coords.
    final points = _participantCameraPoints(includeSelf: !compact);
    if (points.isEmpty) return;

    void apply() {
      if (!_mapHasLayoutSize(map)) return;
      final size = map.camera.nonRotatedSize;
      final padding = compact ? _kCardFitPadding : _kSheetFitPadding;
      final canFit = _canCameraFit(points) &&
          size.width > padding.horizontal &&
          size.height > padding.vertical;

      try {
        if (canFit) {
          map.fitCamera(CameraFit.coordinates(
            coordinates: points,
            padding: padding,
            maxZoom: 13,
          ));
        } else {
          map.move(points.first, 13);
        }
        final center = map.camera.center;
        if (!isFiniteLatLng(center) || !map.camera.zoom.isFinite) {
          map.move(points.first, 13);
        }
      } catch (_) {}
    }

    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isAlive) return;
      apply();
    });
  }

  static bool _mapHasLayoutSize(MapController map) {
    try {
      final size = map.camera.nonRotatedSize;
      return size.width > 0 && size.height > 0;
    } catch (_) {
      return false;
    }
  }

  String friendMarkerKeyFor(FindMyFriend friend) => _friendMarkerKey(friend);

  Handle? handleForFriendMarker(FindMyFriend friend) {
    if (participantFilter != null) {
      for (final participant in participantFilter!) {
        if (FindMyHandleMatcher.matchesFriend(friend, participant)) {
          return participant;
        }
      }
    }
    return friend.handle;
  }

  void _scheduleRefreshGate() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 30), () {
      if (!_isAlive) return;
      canRefresh.value = true;
    });
  }

  void _setupRedactionListeners() {
    _redactedModeListener?.cancel();
    _hideContactInfoListener?.cancel();
    _redactedModeListener = SettingsSvc.settings.redactedMode.listen((_) => _rebuildAllMarkers());
    _hideContactInfoListener = SettingsSvc.settings.hideContactInfo.listen((_) => _rebuildAllMarkers());
  }

  void _rebuildAllMarkers() {
    if (!_isAlive) return;
    for (final friend in friendsWithLocation) {
      buildFriendMarker(friend);
    }
    for (final device in devices.where((e) => e.location?.latitude != null && e.location?.longitude != null)) {
      buildDeviceMarker(device);
    }
    final loc = location.value;
    if (loc != null && (!isParticipantMode || showSelf)) {
      buildLocationMarker(loc);
    }
    markers.refresh();
    if (isParticipantMode) fitMapToParticipantMarkers();
  }

  LatLng markerPointForFriend(FindMyFriend friend) => resolveFindMyMarkerPoint(
        stableKey: friend.stableId ?? friend.title ?? 'friend',
        latitude: friend.latitude!,
        longitude: friend.longitude!,
      );

  LatLng markerPointForDevice(FindMyDevice device) => resolveFindMyMarkerPoint(
        stableKey: device.id ?? device.name ?? 'device',
        latitude: device.location!.latitude!,
        longitude: device.location!.longitude!,
      );

  void _handleNewFindMyLocation(dynamic data) {
    if (!_isAlive) return;
    try {
      final friend = FindMyFriend.fromJson(data);
      Logger.info("Received new location for ${friend.handle?.address}");
      if ((friend.latitude ?? 0) == 0 && (friend.longitude ?? 0) == 0) return;

      final existingFriendIndex = friends.indexWhere((e) => _isSameFindMyFriend(e, friend));
      final existingFriend = existingFriendIndex == -1 ? null : friends[existingFriendIndex];

      final shouldUpdate = existingFriend == null ||
          existingFriend.status == null ||
          friend.locatingInProgress ||
          LocationStatus.values.indexOf(existingFriend.status!) <=
              LocationStatus.values.indexOf(friend.status ?? LocationStatus.legacy);

      // Keep the session snapshot current for any accepted socket update, even
      // when this controller is filtered to a single chat's participants.
      if (shouldUpdate) {
        FindMyParticipantPrefetch.upsertFriend(friend);
      }

      if (isParticipantMode && !matchesParticipantFilter(friend)) return;

      if (shouldUpdate) {
        Logger.info("Updating map for ${friend.stableId}");
        if (existingFriendIndex == -1) {
          friends.add(friend);
        } else {
          friends[existingFriendIndex] = friend;
        }

        friendsWithLocation.value =
            friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
        friendsWithoutLocation.value =
            friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

        buildFriendMarker(friend);
        if (isParticipantMode) fitMapToParticipantMarkers();
      }
    } catch (e, s) {
      Logger.warn("Failed to fetch FindMy locations", error: e, trace: s, tag: 'FindMyController');
    }
  }

  /// Fetches the FindMy data from the server.
  /// The toggles for refresh friends & devices are separate due to an inconsistency in the server API.
  /// As of v1.9.7 (server), the refresh devices endpoint doesn't return the devices data,
  /// however, the refresh friends endpoint does. The way this was coded assumes that the server
  /// will return the data for both endpoints. A server update will fix this, but for now,
  /// we will "patch" it by only "refreshing" devices when the user manually refreshes the data.
  Future<void> getLocations({bool refreshFriends = true, bool refreshDevices = false, bool suppressErrors = false}) async {
    if (!_isAlive) return;

    if (!isParticipantMode) {
      await _startOwnLocationTracking();
    } else if (showSelf) {
      // Don't block friend fetch on the GPS permission prompt.
      unawaited(_startOwnLocationTracking());
    }

    // Fetch friends data
    final response2 = refreshFriends
        ? await HttpSvc.icloud.refreshFriends().catchError((_) async {
            if (!_isAlive) return Response(requestOptions: RequestOptions(path: ''));
            refreshing2.value = false;
            if (!suppressErrors) {
              showSnackbar("Error", "Something went wrong refreshing FindMy Friends data!");
            }
            return Response(requestOptions: RequestOptions(path: ''));
          })
        : await HttpSvc.icloud.getFriends().catchError((_) async {
            if (!_isAlive) return Response(requestOptions: RequestOptions(path: ''));
            fetching2.value = null;
            return Response(requestOptions: RequestOptions(path: ''));
          });
    if (!_isAlive) return;

    if (response2.statusCode == 200 && response2.data['data'] != null) {
      try {
        friends.value =
            (response2.data['data'] as List).map((e) => FindMyFriend.fromJson(e)).toList().cast<FindMyFriend>();

        friendsWithLocation.value =
            friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
        friendsWithoutLocation.value =
            friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

        if (isParticipantMode) {
          _rebuildParticipantMarkers();
          fitMapToParticipantMarkers();
          FindMyParticipantPrefetch.updateSnapshot(friends);
        } else {
          for (final e in friendsWithLocation) {
            buildFriendMarker(e);
          }
        }
        fetching2.value = false;
        refreshing2.value = false;
      } catch (e, s) {
        Logger.error("Failed to parse FindMy Friends location data!", error: e, trace: s);
        fetching2.value = null;
        refreshing2.value = false;
        return;
      }
    } else {
      fetching2.value = false;
      refreshing2.value = false;
    }

    if (isParticipantMode) {
      if (!refreshFriends && FindMyParticipantPrefetch.canPostParticipantRefresh) {
        FindMyParticipantPrefetch.recordParticipantRefresh();
        HttpSvc.icloud.refreshFriends();
      }
      return;
    }

    // Fetch devices data
    final response = refreshDevices
        ? await HttpSvc.icloud.refreshDevices().catchError((_) async {
            if (!_isAlive) return Response(requestOptions: RequestOptions(path: ''));
            refreshing.value = false;
            showSnackbar("Error", "Something went wrong refreshing FindMy Devices data!");
            return Response(requestOptions: RequestOptions(path: ''));
          })
        : await HttpSvc.icloud.getDevices().catchError((_) async {
            if (!_isAlive) return Response(requestOptions: RequestOptions(path: ''));
            fetching.value = null;
            return Response(requestOptions: RequestOptions(path: ''));
          });
    if (!_isAlive) return;

    if (response.statusCode == 200 && response.data['data'] != null) {
      try {
        devices.value =
            (response.data['data'] as List).map((e) => FindMyDevice.fromJson(e)).toList().cast<FindMyDevice>();

        // Apply safe location name as the display label once, here rather than during build.
        for (final device in devices) {
          if (device.safeLocations.isNotEmpty && device.safeLocations.first.name != null) {
            device.address?.label = device.safeLocations.first.name;
          }
        }

        for (FindMyDevice e in devices.where((e) => e.location?.latitude != null && e.location?.longitude != null)) {
          buildDeviceMarker(e);
        }
        fetching.value = false;
        refreshing.value = false;
      } catch (e, s) {
        Logger.error("Failed to parse FindMy Devices location data!", error: e, trace: s);
        fetching.value = null;
        refreshing.value = false;
        return;
      }
    } else {
      fetching.value = false;
      refreshing.value = false;
    }

    // Call the FindMy Friends refresh anyways so that new data comes through the socket
    if (!refreshFriends) {
      HttpSvc.icloud.refreshFriends();
    } else {
      canRefresh.value = false;
      _scheduleRefreshGate();
    }
  }

  void buildDeviceMarker(FindMyDevice e) {
    markers[e.id ?? randomString(6)] = Marker(
      key: ValueKey('device-${e.id ?? randomString(6)}'),
      point: markerPointForDevice(e),
      width: 30,
      height: 35,
      child: ClipShadowPath(
        clipper: const FindMyPinClipper(),
        shadow: const BoxShadow(
          color: Colors.black,
          blurRadius: 2,
        ),
        child: Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: e.role?['emoji'] != null
                  ? Text(e.role!['emoji'],
                      style: Get.context!.theme.textTheme.bodyLarge!.copyWith(fontFamily: 'Apple Color Emoji'))
                  : Icon(
                      (e.isMac ?? false)
                          ? Icons.computer
                          : e.isConsideredAccessory
                              ? Icons.headphones
                              : Icons.phone_iphone,
                      color: Colors.black,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
      alignment: Alignment.topCenter,
    );
  }

  void buildFriendMarker(FindMyFriend friend) {
    final markerKey = _friendMarkerKey(friend);
    if (isParticipantMode && !matchesParticipantFilter(friend)) {
      markers.remove(markerKey);
      return;
    }
    markers[markerKey] = Marker(
      key: ValueKey('friend-$markerKey'),
      point: markerPointForFriend(friend),
      width: 35,
      height: 35,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ContactAvatarWidget(
              editable: false,
              size: 29,
              scaleSize: false,
              borderThickness: 0,
              handle: isParticipantMode ? handleForFriendMarker(friend) : friend.handle,
            ),
          ),
        ),
      ),
      alignment: isParticipantMode ? Alignment.center : Alignment.topCenter,
    );
  }

  Future<void> _startOwnLocationTracking() async {
    if (_ownLocationStarted) return;
    if (Platform.isLinux && !kIsWeb) return;
    _ownLocationStarted = true;

    LocationPermission granted = await Geolocator.checkPermission();
    if (!_isAlive) return;
    if (granted == LocationPermission.denied) {
      granted = await Geolocator.requestPermission();
      if (!_isAlive) return;
    }

    if (granted != LocationPermission.whileInUse && granted != LocationPermission.always) {
      return;
    }

    Geolocator.getCurrentPosition().then((loc) {
      if (!_isAlive) return;
      _onOwnLocation(loc, fromStream: false);
      if (kIsDesktop) return;

      locationSub = Geolocator.getPositionStream().listen((event) {
        if (!_isAlive) return;
        _onOwnLocation(event, fromStream: true);
      });
    }).catchError((_) {});
  }

  bool _isUsablePosition(Position pos) {
    final point = LatLng(pos.latitude, pos.longitude);
    return isFiniteLatLng(point);
  }

  void _onOwnLocation(Position pos, {required bool fromStream}) {
    if (!_isUsablePosition(pos)) return;

    final isFirst = !markers.containsKey(_kCurrentMarkerKey);
    location.value = pos;
    buildLocationMarker(pos);

    if (isParticipantMode) {
      if (!showSelf || !isFirst) return;
      if (_participantMapReady) {
        fitMapToParticipantMarkers();
      } else {
        _pendingOwnLocationFit = true;
      }
      return;
    }

    if (fromStream && !hasMovedToCurrentLocation.value) {
      mapController.move(LatLng(pos.latitude, pos.longitude), 10);
      hasMovedToCurrentLocation.value = true;
    }
  }

  void buildLocationMarker(Position pos) {
    if (isParticipantMode && !showSelf) return;
    if (!_isUsablePosition(pos)) return;
    markers[_kCurrentMarkerKey] = Marker(
      key: const ValueKey(_kCurrentMarkerKey),
      point: LatLng(pos.latitude, pos.longitude),
      width: 25,
      height: 55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pos.heading.isFinite)
            Transform.rotate(
              angle: pos.heading,
              child: ClipPath(
                clipper: const FindMyLocationClipper(),
                child: Container(
                  width: 25,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.center,
                      end: Alignment.topCenter,
                      colors: [
                        Get.context!.theme.colorScheme.primary,
                        Get.context!.theme.colorScheme.primary.withAlpha(50)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 25,
            height: 25,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Get.context!.theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      alignment: Alignment.topCenter,
    );
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _redactedModeListener?.cancel();
    _hideContactInfoListener?.cancel();
    _findMyLocationListener?.cancel();
    locationSub?.cancel();
    mapController.dispose();
    popupController.dispose();
    tabController?.dispose();
    itemsController.dispose();
    devicesController.dispose();
    friendsController.dispose();
    super.onClose();
  }
}
