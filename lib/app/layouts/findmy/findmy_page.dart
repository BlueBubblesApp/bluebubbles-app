import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_location_clipper.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:get/get.dart' hide Response;
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:universal_io/io.dart';

class FindMyPage extends StatefulWidget {
  const FindMyPage({super.key});

  @override
  State<StatefulWidget> createState() => _FindMyPageState();
}

class _FindMyPageState extends OptimizedState<FindMyPage> with SingleTickerProviderStateMixin {
  final ScrollController controller1 = ScrollController();
  final ScrollController controller2 = ScrollController();
  late final TabController tabController = TabController(vsync: this, length: 2);
  final PanelController panelController = PanelController();
  final RxInt index = 0.obs;
  final PopupController popupController = PopupController();
  final MapController mapController = MapController();
  final completer = Completer<void>();

  StreamSubscription? locationSub;
  List<FindMyDevice> devices = [];
  List<FindMyFriend> friends = [];
  List<FindMyFriend> friendsWithLocation = [];
  List<FindMyFriend> friendsWithoutLocation = [];
  Map<String, Marker> markers = {};
  Position? location;
  bool? fetching = true;
  bool refreshing = false;
  bool? fetching2 = true;
  bool refreshing2 = false;
  bool canRefresh = false;

  @override
  void initState() {
    super.initState();
    getLocations();

    socket.socket.on("new-findmy-location", (data) {
      try {
        final friend = FindMyFriend.fromJson(data);
        Logger.info("Received new location for ${friend.handle?.address}");
        if ((friend.latitude ?? 0) == 0 && (friend.longitude ?? 0) == 0) return;
        final existingFriendIndex = friends.indexWhere((e) => e.handle?.uniqueAddressAndService == friend.handle?.uniqueAddressAndService);
        final existingFriend = existingFriendIndex == -1 ? null : friends[existingFriendIndex];
        if (existingFriend == null || existingFriend.status == null || friend.locatingInProgress || LocationStatus.values.indexOf(existingFriend.status!) <= LocationStatus.values.indexOf(friend.status ?? LocationStatus.legacy)) {
          Logger.info("Updating map for ${friend.handle?.address}");
          friends[existingFriendIndex] = friend;

          friendsWithLocation = friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
          friendsWithoutLocation = friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

          buildFriendMarker(friend);
          setState(() {});
        }
      } catch (_) {}
    });

    // Allow users to refresh after 30sec
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          canRefresh = true;
        });
      }
    });
  }

  void getLocations({bool refreshFriends = true, bool refreshDevices = false}) async {
    if (!(Platform.isLinux && !kIsWeb)) {
      LocationPermission granted = await Geolocator.checkPermission();
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.whileInUse || granted == LocationPermission.always) {
        Geolocator.getCurrentPosition().then((loc) {
          location = loc;
          buildLocationMarker(location!);
          if (!kIsDesktop) {
            locationSub = Geolocator.getPositionStream().listen((event) {
              setState(() {
                buildLocationMarker(event);
              });
            });
          }
          if (!refreshFriends) {
            mapController.move(LatLng(location!.latitude, location!.longitude), 10);
          }
        });
      }
    }

    final response2 = refreshFriends
        ? await http.refreshFindMyFriends().catchError((_) async {
      setState(() {
        refreshing2 = false;
      });
      showSnackbar("Error", "Something went wrong refreshing FindMy Friends data!");
      return Response(requestOptions: RequestOptions(path: ''));
    })
        : await http.findMyFriends().catchError((_) async {
      setState(() {
        fetching2 = null;
      });
      return Response(requestOptions: RequestOptions(path: ''));
    });
    if (response2.statusCode == 200 && response2.data['data'] != null) {
      try {
        friends = (response2.data['data'] as List)
            .map((e) => FindMyFriend.fromJson(e))
            .toList()
            .cast<FindMyFriend>();

        friendsWithLocation = friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
        friendsWithoutLocation = friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

        for (FindMyFriend e in friendsWithLocation) {
          buildFriendMarker(e);
        }
        setState(() {
          fetching2 = false;
          refreshing2 = false;
        });
      } catch (e, s) {
        Logger.error("Failed to parse FindMy Friends location data!", error: e, trace: s);
        setState(() {
          fetching2 = null;
          refreshing2 = false;
        });
        return;
      }
    } else {
      setState(() {
        fetching2 = false;
        refreshing2 = false;
      });
    }

    final response = refreshDevices
        ? await http.refreshFindMyDevices().catchError((_) async {
            setState(() {
              refreshing = false;
            });
            showSnackbar("Error", "Something went wrong refreshing FindMy Devices data!");
            return Response(requestOptions: RequestOptions(path: ''));
          })
        : await http.findMyDevices().catchError((_) async {
            setState(() {
              fetching = null;
            });
            return Response(requestOptions: RequestOptions(path: ''));
          });
    if (response.statusCode == 200 && response.data['data'] != null) {
      try {
        devices = (response.data['data'] as List).map((e) => FindMyDevice.fromJson(e)).toList().cast<FindMyDevice>();
        for (FindMyDevice e in devices.where((e) => e.location?.latitude != null && e.location?.longitude != null)) {
          markers[e.id ?? randomString(6)] = Marker(
            key: ValueKey('device-${e.id ?? randomString(6)}'),
            point: LatLng(e.location!.latitude!, e.location!.longitude!),
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
                            style: context.theme.textTheme.bodyLarge!.copyWith(fontFamily: 'Apple Color Emoji'))
                        : Icon(
                            (e.isMac ?? false)
                                ? CupertinoIcons.desktopcomputer
                                : e.isConsideredAccessory
                                    ? CupertinoIcons.headphones
                                    : CupertinoIcons.device_phone_portrait,
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
        setState(() {
          fetching = false;
          refreshing = false;
        });
      } catch (e, s) {
        Logger.error("Failed to parse FindMy Devices location data!", error: e, trace: s);
        setState(() {
          fetching = null;
          refreshing = false;
        });
        return;
      }
    } else {
      setState(() {
        fetching = false;
        refreshing = false;
      });
    }

    // Call the FindMy Friends refresh anyways so that new data comes through the socket
    if (!refreshFriends) {
      http.refreshFindMyFriends();
    } else {
      setState(() {
        canRefresh = false;
      });
      // Allow users to refresh after 30sec
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            canRefresh = true;
          });
        }
      });
    }
  }

  void buildFriendMarker(FindMyFriend friend) {
    markers[friend.handle?.uniqueAddressAndService ?? randomString(6)] = Marker(
      key: ValueKey('friend-${friend.handle?.uniqueAddressAndService ?? randomString(6)}'),
      point: LatLng(friend.latitude!, friend.longitude!),
      width: 35,
      height: 35,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child:
            ContactAvatarWidget(editable: false, handle: friend.handle ?? Handle(address: friend.title ?? "Unknown")),
          ),
        ),
      ),
      alignment: Alignment.topCenter,
    );
  }

  void buildLocationMarker(Position pos) {
    markers['current'] = Marker(
      key: const ValueKey('current'),
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
                      colors: [context.theme.colorScheme.primary, context.theme.colorScheme.primary.withAlpha(50)],
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
                color: context.theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      alignment: Alignment.topCenter,
    );
  }

  @override
  void dispose() {
    locationSub?.cancel();
    mapController.dispose();
    popupController.dispose();
    tabController.dispose();
    socket.socket.off("new-findmy-location");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicesWithLocation = devices
        .where(
            (item) => (item.address?.label ?? item.address?.mapItemFullAddress) != null && !item.isConsideredAccessory)
        .toList();
    final itemsWithLocation = devices
        .where(
            (item) => (item.address?.label ?? item.address?.mapItemFullAddress) != null && item.isConsideredAccessory)
        .toList();
    final withoutLocation =
        devices.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) == null).toList();
    final devicesBodySlivers = [
      SliverList(
        delegate: SliverChildListDelegate([
          if (fetching == null || fetching == true || (fetching == false && devices.isEmpty))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        fetching == null
                            ? "Something went wrong!"
                            : fetching == false
                                ? "You have no devices."
                                : "Getting FindMy data...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    if (fetching == true) buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            ),
          if (devicesWithLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Devices"),
          if (devicesWithLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    findChildIndexCallback: (key) => findChildIndexByKey(devicesWithLocation, key, (item) => item.address?.uniqueValue),
                    itemBuilder: (context, i) {
                      final item = devicesWithLocation[i];
                      return ListTile(
                        key: ValueKey(item.address?.uniqueValue),
                        mouseCursor: MouseCursor.defer,
                        title: Text(ss.settings.redactedMode.value ? "Device" : (item.name ?? "Unknown Device")),
                        subtitle: Text(ss.settings.redactedMode.value ? "Location" : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found")),
                        onTap: item.location?.latitude != null && item.location?.longitude != null
                            ? () async {
                                await panelController.close();
                                await completer.future;
                                final marker = markers.values.firstWhere((e) =>
                                    e.point.latitude == item.location?.latitude &&
                                    e.point.longitude == item.location?.longitude);
                                popupController.showPopupsOnlyFor([marker]);
                                mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                              }
                            : null,
                        trailing: item.location?.latitude != null && item.location?.longitude != null ? ButtonTheme(
                          minWidth: 1,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: context.theme.colorScheme.primaryContainer,
                            ),
                            onPressed: () async {
                              await MapsLauncher.launchCoordinates(item.location!.latitude!, item.location!.longitude!);
                            },
                            child: const Icon(
                                Icons.directions,
                                size: 20
                            ),
                          ),
                        ) : null,
                        onLongPress: () async {
                          const encoder = JsonEncoder.withIndent("     ");
                          final str = encoder.convert(item.toJson());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                "Raw FindMy Data",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: SizedBox(
                                width: ns.width(context) * 3 / 5,
                                height: context.height * 1 / 4,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background,
                                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      str,
                                      style: context.theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Close",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    itemCount: devicesWithLocation.length,
                  ),
                ),
              ],
            ),
          if (itemsWithLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Items"),
          if (itemsWithLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    findChildIndexCallback: (key) => findChildIndexByKey(itemsWithLocation, key, (item) => item.address?.uniqueValue),
                    itemBuilder: (context, i) {
                      final item = itemsWithLocation[i];
                      return ListTile(
                        key: ValueKey(item.address?.uniqueValue),
                        title: Text(ss.settings.redactedMode.value ? "Item" : (item.name ?? "Unknown Item")),
                        subtitle: Text(ss.settings.redactedMode.value ? "Location" : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found")),
                        trailing: item.location?.latitude != null && item.location?.longitude != null ? ButtonTheme(
                          minWidth: 1,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: context.theme.colorScheme.primaryContainer,
                            ),
                            onPressed: () async {
                              await MapsLauncher.launchCoordinates(item.location!.latitude!, item.location!.longitude!);
                            },
                            child: const Icon(
                                Icons.directions,
                                size: 20
                            ),
                          ),
                        ) : null,
                        onTap: item.location?.latitude != null && item.location?.longitude != null
                            ? () async {
                                await panelController.close();
                                await completer.future;
                                final marker = markers.values.firstWhere((e) =>
                                    e.point.latitude == item.location?.latitude &&
                                    e.point.longitude == item.location?.longitude);
                                popupController.showPopupsOnlyFor([marker]);
                                mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                              }
                            : null,
                        onLongPress: () async {
                          const encoder = JsonEncoder.withIndent("     ");
                          final str = encoder.convert(item.toJson());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                "Raw FindMy Data",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: SizedBox(
                                width: ns.width(context) * 3 / 5,
                                height: context.height * 1 / 4,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background,
                                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      str,
                                      style: context.theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Close",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    itemCount: itemsWithLocation.length,
                  ),
                ),
              ],
            ),
          if (withoutLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Unknown Location"),
          if (withoutLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.transparent)),
                      title: const Text("Devices without locations"),
                      children: withoutLocation
                          .map((item) => ListTile(
                                title: Text(ss.settings.redactedMode.value ? "Device" : (item.name ?? "Unknown Device")),
                                subtitle: Text(ss.settings.redactedMode.value ? "Location" : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found")),
                                onTap: item.location?.latitude != null && item.location?.longitude != null
                                    ? () async {
                                        await panelController.close();
                                        await completer.future;
                                        final marker = markers.values.firstWhere((e) =>
                                            e.point.latitude == item.location?.latitude &&
                                            e.point.longitude == item.location?.longitude);
                                        popupController.showPopupsOnlyFor([marker]);
                                        mapController.move(
                                            LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                                      }
                                    : null,
                                onLongPress: () async {
                                  const encoder = JsonEncoder.withIndent("     ");
                                  final str = encoder.convert(item.toJson());
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        "Raw FindMy Data",
                                        style: context.theme.textTheme.titleLarge,
                                      ),
                                      backgroundColor: context.theme.colorScheme.properSurface,
                                      content: SizedBox(
                                        width: ns.width(context) * 3 / 5,
                                        height: context.height * 1 / 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                              color: context.theme.colorScheme.background,
                                              borderRadius: const BorderRadius.all(Radius.circular(10))),
                                          child: SingleChildScrollView(
                                            child: SelectableText(
                                              str,
                                              style: context.theme.textTheme.bodyLarge,
                                            ),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: Text("Close",
                                              style: context.theme.textTheme.bodyLarge!
                                                  .copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ))
                          .toList()),
                ),
              ],
            ),
        ]),
      ),
    ];

    final friendsBodySlivers = [
      SliverList(
        delegate: SliverChildListDelegate([
          if (fetching2 == null || fetching2 == true || (fetching2 == false && friends.isEmpty))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        fetching2 == null
                            ? "Something went wrong!"
                            : fetching2 == false
                                ? "You have no friends."
                                : "Getting FindMy data...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    if (fetching2 == true) buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            ),
          if (friendsWithLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Friends"),
          if (friendsWithLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    findChildIndexCallback: (key) => findChildIndexByKey(friendsWithLocation, key, (item) => item.handle?.uniqueAddressAndService),
                    itemBuilder: (context, i) {
                      final item = friendsWithLocation[i];
                      return ListTile(
                        key: ValueKey(item.handle?.uniqueAddressAndService),
                        leading: ContactAvatarWidget(handle: item.handle),
                        title: Text(item.handle?.displayName ?? item.title ?? "Unknown Friend"),
                        subtitle: Text(ss.settings.redactedMode.value ? "Location" : ("${item.shortAddress ?? "No location found"}${item.lastUpdated == null || item.status == LocationStatus.live ? "" : "\nLast updated ${buildDate(item.lastUpdated)}"}")),
                        trailing: item.latitude != null && item.longitude != null ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.status == LocationStatus.live)
                              const Icon(CupertinoIcons.largecircle_fill_circle),
                            if (item.locatingInProgress)
                              buildProgressIndicator(context),
                            ButtonTheme(
                              minWidth: 1,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: context.theme.colorScheme.primaryContainer,
                                ),
                                onPressed: () async {
                                  await MapsLauncher.launchCoordinates(item.latitude!, item.longitude!);
                                },
                                child: const Icon(
                                    Icons.directions,
                                    size: 20
                                ),
                              ),
                            ),
                          ],
                        ) : null,
                        onTap: () async {
                          if (context.isPhone) {
                            await panelController.close();
                          }
                          await completer.future;
                          final marker = markers.values.firstWhere(
                              (e) => e.point.latitude == item.latitude && e.point.longitude == item.longitude);
                          popupController.showPopupsOnlyFor([marker]);
                          mapController.move(LatLng(item.latitude!, item.longitude!), 10);
                        },
                        onLongPress: () async {
                          const encoder = JsonEncoder.withIndent("     ");
                          final str = encoder.convert(item.toJson());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                "Raw FindMy Data",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: SizedBox(
                                width: ns.width(context) * 3 / 5,
                                height: context.height / 2,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background,
                                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      str,
                                      style: context.theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Close",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    itemCount: friendsWithLocation.length,
                  ),
                ),
              ],
            ),
          if (friendsWithoutLocation.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Unknown Location"),
          if (friendsWithoutLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.transparent)),
                      title: const Text("Friends without locations"),
                      children: friendsWithoutLocation
                          .map((item) => ListTile(
                                mouseCursor: MouseCursor.defer,
                                leading: ContactAvatarWidget(handle: item.handle),
                                title: Text(item.handle?.displayName ?? item.title ?? "Unknown Friend"),
                                subtitle: Text(ss.settings.redactedMode.value ? "Location" : (item.longAddress ?? "No location found")),
                                onLongPress: () async {
                                  const encoder = JsonEncoder.withIndent("     ");
                                  final str = encoder.convert(item.toJson());
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        "Raw FindMy Data",
                                        style: context.theme.textTheme.titleLarge,
                                      ),
                                      backgroundColor: context.theme.colorScheme.properSurface,
                                      content: SizedBox(
                                        width: ns.width(context) * 3 / 5,
                                        height: context.height * 1 / 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                              color: context.theme.colorScheme.background,
                                              borderRadius: const BorderRadius.all(Radius.circular(10))),
                                          child: SingleChildScrollView(
                                            child: SelectableText(
                                              str,
                                              style: context.theme.textTheme.bodyLarge,
                                            ),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: Text("Close",
                                              style: context.theme.textTheme.bodyLarge!
                                                  .copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ))
                          .toList()),
                ),
              ],
            ),
        ]),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: ss.settings.immersiveMode.value
              ? Colors.transparent
              : context.theme.colorScheme.background, // navigation bar color
          systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
          statusBarColor: Colors.transparent, // status bar color
          statusBarIconBrightness: Brightness.dark,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (context.isPhone) {
              return buildNormal(context, devicesBodySlivers, friendsBodySlivers);
            }
            return buildTabletLayout(context, devicesBodySlivers, friendsBodySlivers);
          },
        ));
  }

  Widget buildTabletLayout(BuildContext context, List<SliverList> devicesBodySlivers, List<SliverList> friendsBodySlivers) {
    return Obx(
      () => Scaffold(
        backgroundColor: context.theme.colorScheme.background.themeOpacity(context),
        body: Stack(
          children: [
            Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 300, maxWidth: max(300, min(500, ns.width(context) / 3))),
                  child: Container(
                    width: 500,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      buildMap(),
                      if (!samsung && canRefresh)
                        Positioned(
                          top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                          right: 20,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.properSurface.withOpacity(0.9),
                            ),
                            child: Container(
                              width: 48,
                              child: refreshing || refreshing2
                                  ? buildProgressIndicator(context)
                                  : IconButton(
                                      iconSize: 22,
                                      icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                                          color: context.theme.colorScheme.onBackground, size: 22),
                                      onPressed: () {
                                        setState(() {
                                          refreshing = true;
                                          refreshing2 = true;
                                        });
                                        getLocations();
                                      },
                                    ),
                            ),
                          ),
                        ),
                      if (kIsDesktop)
                        SizedBox(
                          height: appWindow.titleBarHeight,
                          child: AbsorbPointer(
                            child: Row(children: [
                              Expanded(child: Container()),
                              ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaY: 2, sigmaX: 2),
                                  child: Container(
                                      height: appWindow.titleBarHeight,
                                      width: appWindow.titleBarButtonSize.width * 3,
                                      color: context.theme.colorScheme.properSurface.withOpacity(0.5)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 300, maxWidth: max(300, min(500, ns.width(context) / 3))),
              child: Column(
                children: [
                  if (!samsung)
                    Container(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: buildBackButton(context),
                          ),
                          Expanded(child: Text("Find My", style: context.theme.textTheme.titleLarge)),
                        ],
                      ),
                    ),
                  if (!samsung) buildDesktopTabBar(),
                  Expanded(
                    child: Container(
                      width: 500,
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          ScrollbarWrapper(
                            controller: controller1,
                            child: CustomScrollView(
                              controller: controller1,
                              slivers: [
                                if (samsung) buildSamsungAppBar(context, "FindMy Devices"),
                                if (ss.settings.skin.value != Skins.Samsung) ...devicesBodySlivers,
                                if (ss.settings.skin.value == Skins.Samsung)
                                  SliverToBoxAdapter(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: context.height -
                                              50 -
                                              context.mediaQueryPadding.top -
                                              context.mediaQueryViewPadding.top),
                                      child: CustomScrollView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        slivers: devicesBodySlivers,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ScrollbarWrapper(
                            controller: controller2,
                            child: CustomScrollView(
                              controller: controller2,
                              slivers: [
                                if (samsung) buildSamsungAppBar(context, "FindMy Friends"),
                                if (!samsung) ...friendsBodySlivers,
                                if (samsung)
                                  SliverToBoxAdapter(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: context.height -
                                              50 -
                                              context.mediaQueryPadding.top -
                                              context.mediaQueryViewPadding.top),
                                      child: CustomScrollView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        slivers: friendsBodySlivers,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (samsung) buildDesktopTabBar()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDesktopTabBar() {
    return TabBar(
      controller: tabController,
      dividerColor: context.theme.dividerColor.withOpacity(0.2),
      tabs: [
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iOS ? CupertinoIcons.device_desktop : Icons.devices),
              const Text("Devices"),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iOS ? CupertinoIcons.person_2 : Icons.person),
              const Text("Friends"),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNormal(BuildContext context, List<SliverList> devicesBodySlivers, List<SliverList> friendsBodySlivers) {
    return Obx(
      () => Scaffold(
        backgroundColor: material ? tileColor : headerColor,
        body: Stack(
          children: [
            SlidingUpPanel(
              controller: panelController,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25.0),
                topRight: Radius.circular(25.0),
              ),
              minHeight: 50,
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              disableDraggableOnScrolling: true,
              backdropEnabled: true,
              parallaxEnabled: true,
              header: ForceDraggableWidget(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              panelBuilder: () => TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: tabController,
                children: <Widget>[
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                      final scrollDistance = context.height / 3 - 57;

                      if (controller1.offset > 0 && controller1.offset < scrollDistance) {
                        final double snapOffset = controller1.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                        Future.microtask(() => controller1.animateTo(snapOffset,
                            duration: const Duration(milliseconds: 200), curve: Curves.linear));
                      }
                      return false;
                    },
                    child: ScrollbarWrapper(
                      controller: controller1,
                      child: Obx(
                        () => CustomScrollView(
                          controller: controller1,
                          physics: (kIsDesktop || kIsWeb)
                              ? const NeverScrollableScrollPhysics()
                              : ThemeSwitcher.getScrollPhysics(),
                          slivers: <Widget>[
                            if (samsung) buildSamsungAppBar(context, "FindMy Devices"),
                            if (ss.settings.skin.value != Skins.Samsung) ...devicesBodySlivers,
                            if (ss.settings.skin.value == Skins.Samsung)
                              SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: context.height -
                                          50 -
                                          context.mediaQueryPadding.top -
                                          context.mediaQueryViewPadding.top),
                                  child: CustomScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    slivers: devicesBodySlivers,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                      final scrollDistance = context.height / 3 - 57;

                      if (controller2.offset > 0 && controller2.offset < scrollDistance) {
                        final double snapOffset = controller2.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                        Future.microtask(() => controller2.animateTo(snapOffset,
                            duration: const Duration(milliseconds: 200), curve: Curves.linear));
                      }
                      return false;
                    },
                    child: ScrollbarWrapper(
                      controller: controller2,
                      child: Obx(
                        () => CustomScrollView(
                          controller: controller2,
                          physics: (kIsDesktop || kIsWeb)
                              ? const NeverScrollableScrollPhysics()
                              : ThemeSwitcher.getScrollPhysics(),
                          slivers: <Widget>[
                            if (samsung) buildSamsungAppBar(context, "FindMy Friends"),
                            if (ss.settings.skin.value != Skins.Samsung) ...friendsBodySlivers,
                            if (ss.settings.skin.value == Skins.Samsung)
                              SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: context.height -
                                          50 -
                                          context.mediaQueryPadding.top -
                                          context.mediaQueryViewPadding.top),
                                  child: CustomScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    slivers: friendsBodySlivers,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: buildMap(),
            ),
            if (!samsung)
              Positioned(
                  top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                  left: 20,
                  child: Container(
                    width: 48,
                    height: 48,
                    child: buildBackButton(context, padding: const EdgeInsets.only(right: 2)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.properSurface.withOpacity(0.9),
                    ),
                  )),
            if (!samsung && canRefresh)
              Positioned(
                top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                right: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.properSurface.withOpacity(0.9),
                  ),
                  child: Container(
                    width: 48,
                    child: refreshing || refreshing2
                        ? buildProgressIndicator(context)
                        : IconButton(
                            iconSize: 22,
                            icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                                color: context.theme.colorScheme.onBackground, size: 22),
                            onPressed: () {
                              setState(() {
                                refreshing = true;
                                refreshing2 = true;
                              });
                              getLocations(refreshDevices: true);
                            },
                          ),
                  ),
                ),
              ),
            if (kIsDesktop)
              SizedBox(
                height: appWindow.titleBarHeight,
                child: AbsorbPointer(
                  child: Row(children: [
                    Expanded(child: Container()),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaY: 2, sigmaX: 2),
                        child: Container(
                            height: appWindow.titleBarHeight,
                            width: appWindow.titleBarButtonSize.width * 3,
                            color: context.theme.colorScheme.properSurface.withOpacity(0.5)),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index.value,
          backgroundColor: headerColor,
          destinations: [
            NavigationDestination(
              icon: Icon(iOS ? CupertinoIcons.device_desktop : Icons.devices),
              label: "DEVICES",
            ),
            NavigationDestination(
              icon: Icon(iOS ? CupertinoIcons.person_2 : Icons.person),
              label: "FRIENDS",
            ),
          ],
          onDestinationSelected: (page) {
            index.value = page;
            tabController.animateTo(page);
            if (index.value == page && panelController.isPanelOpen) {
              panelController.close();
            } else {
              panelController.open();
            }
          },
        ),
      ),
    );
  }

  Widget buildSamsungAppBar(BuildContext context, String title) {
    final actions = [
      if (canRefresh)
        Container(
          width: 48,
          height: 48,
          child: Container(
            width: 48,
            margin: const EdgeInsets.only(right: 8),
            child: refreshing || refreshing2
                ? buildProgressIndicator(context)
                : IconButton(
                    iconSize: 22,
                    icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                        color: context.theme.colorScheme.onBackground, size: 22),
                    onPressed: () {
                      setState(() {
                        refreshing = true;
                        refreshing2 = true;
                      });
                      getLocations(refreshDevices: true);
                    },
                  ),
          ),
        ),
    ];

    return SliverAppBar(
      backgroundColor: headerColor,
      pinned: true,
      stretch: true,
      expandedHeight: context.height / 3,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          var expandRatio = (constraints.maxHeight - 50) / (context.height / 3 - 50);

          if (expandRatio > 1.0) expandRatio = 1.0;
          if (expandRatio < 0.0) expandRatio = 0.0;
          final animation = AlwaysStoppedAnimation<double>(expandRatio);

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
                )),
                child: Center(
                    child: Text(title,
                        style: context.theme.textTheme.displaySmall!
                            .copyWith(color: context.theme.colorScheme.onBackground),
                        textAlign: TextAlign.center)),
              ),
              FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                )),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.only(left: 40),
                    height: 50,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: context.theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    height: 50,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: buildBackButton(context),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 50,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialZoom: 5.0,
        minZoom: 1.0,
        maxZoom: 18.0,
        initialCenter: location == null ? const LatLng(0, 0) : LatLng(location!.latitude, location!.longitude),
        onTap: (_, __) => popupController.hideAllPopups(),
        // Hide popup when the map is tapped.
        keepAlive: true,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          if (!completer.isCompleted) {
            completer.complete();
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
            popupController: popupController,
            markers: markers.values.toList(),
            popupDisplayOptions: PopupDisplayOptions(
              builder: (context, marker) {
                final ValueKey? key = marker.key as ValueKey?;
                if (key?.value == "current") return const SizedBox();
                if (key?.value.contains("device")) {
                  final item = devices.firstWhere((e) =>
                      e.location?.latitude == marker.point.latitude && e.location?.longitude == marker.point.longitude);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: context.theme.colorScheme.properSurface.withOpacity(0.8),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ss.settings.redactedMode.value ? "Device" : (item.name ?? "Unknown Device"), style: context.theme.textTheme.labelLarge),
                          Text(ss.settings.redactedMode.value ? "Location" : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found"),
                              style: context.theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                } else {
                  final item = friends
                      .firstWhere((e) => e.latitude == marker.point.latitude && e.longitude == marker.point.longitude);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: context.theme.colorScheme.properSurface.withOpacity(0.8),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.handle?.displayName ?? item.title ?? "Unknown Friend",
                              style: context.theme.textTheme.labelLarge),
                          Text(ss.settings.redactedMode.value ? "Location" : (item.longAddress ?? "No location found"), style: context.theme.textTheme.bodySmall),
                          if (item.lastUpdated != null && item.status != LocationStatus.live)
                            Text("Last updated ${buildDate(item.lastUpdated)}", style: context.theme.textTheme.bodySmall),
                          if (item.status != null)
                            Text("${item.status!.name.capitalize!} Location", style: context.theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
