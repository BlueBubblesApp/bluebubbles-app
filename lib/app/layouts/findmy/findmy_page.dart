import 'dart:convert';
import 'dart:async';

import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
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

class FindMyPage extends StatefulWidget {
  const FindMyPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _FindMyPageState();
}

class _FindMyPageState extends OptimizedState<FindMyPage> with SingleTickerProviderStateMixin {
  final ScrollController controller1 = ScrollController();
  late final TabController tabController = TabController(vsync: this, length: 2);
  final RxInt index = 0.obs;
  final PopupController popupController = PopupController();
  final MapController mapController = MapController();
  final completer = Completer<void>();

  List<FindMy> devices = [];
  List<Marker> markers = [];
  Position? location;
  bool? fetching = true;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    getLocations();
  }

  void getLocations({bool refresh = false}) async {
    final response = refresh ? await http.refreshFindMyDevices().catchError((_) async {
      setState(() {
        refreshing = false;
      });
      showSnackbar("Error", "Something went wrong refreshing FindMy data!");
      return Response(requestOptions: RequestOptions(path: ''));
    }) : await http.findMyDevices().catchError((_) async {
      setState(() {
        fetching = null;
      });
      return Response(requestOptions: RequestOptions(path: ''));
    });
    if (response.statusCode == 200 && response.data['data'] != null) {
      try {
        devices = (response.data['data'] as List).map((e) => FindMy.fromJson(e)).toList().cast<FindMy>();
        markers = devices.where((e) => e.location?.latitude != null && e.location?.longitude != null).map((e) => Marker(
          point: LatLng(e.location!.latitude!, e.location!.longitude!),
          width: 30,
          height: 35,
          builder: (_) => ClipShadowPath(
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
                  child: e.role?['emoji'] != null ? Text(e.role!['emoji'], style: context.theme.textTheme.bodyLarge!.copyWith(fontFamily: 'Apple Color Emoji'))
                      : Icon((e.isMac ?? false)
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
          anchorPos: AnchorPos.align(AnchorAlign.top),
        )).toList();
        final granted = await Geolocator.checkPermission();
        if (granted == LocationPermission.whileInUse || granted == LocationPermission.always) {
          location = await Geolocator.getCurrentPosition();
          markers.add(
            Marker(
              point: LatLng(location!.latitude, location!.longitude),
              width: 25,
              height: 25,
              builder: (_) => Container(
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
              anchorPos: AnchorPos.align(AnchorAlign.center),
            ),
          );
        }
        setState(() {
          fetching = false;
          refreshing = false;
        });
      } catch (e, s) {
        Logger.error(e);
        Logger.error(s);
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
  }


  @override
  Widget build(BuildContext context) {
    final devicesWithLocation = devices.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) != null && !item.isConsideredAccessory).toList();
    final itemsWithLocation = devices.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) != null && item.isConsideredAccessory).toList();
    final withoutLocation = devices.where((item) => (item.address?.label ?? item.address?.mapItemFullAddress) == null).toList();
    final bodySlivers = [
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
                        fetching == null ? "Something went wrong!" : fetching == false ? "You have no devices or friends." : "Getting FindMy data...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    if (fetching == true)
                      buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            ),
          if (devicesWithLocation.isNotEmpty)
            SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Devices"),
          if (devicesWithLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (context, i) {
                      final item = devicesWithLocation[i];
                      return ListTile(
                        mouseCursor: MouseCursor.defer,
                        title: Text(item.name ?? "Unknown Device"),
                        subtitle: Text(item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found"),
                        onTap: item.location?.latitude != null && item.location?.longitude != null ? () async {
                          index.value = 1;
                          tabController.animateTo(1);
                          await completer.future;
                          final marker = markers.firstWhere((e) => e.point.latitude == item.location?.latitude && e.point.longitude == item.location?.longitude);
                          popupController.showPopupsOnlyFor([marker]);
                          mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                        } : null,
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
                                      borderRadius: const BorderRadius.all(Radius.circular(10))
                                  ),
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
                                  child: Text(
                                      "Close",
                                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
                                  ),
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
            SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Items"),
          if (itemsWithLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (context, i) {
                      final item = itemsWithLocation[i];
                      return ListTile(
                        mouseCursor: MouseCursor.defer,
                        title: Text(item.name ?? "Unknown Device"),
                        subtitle: Text(item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found"),
                        onTap: item.location?.latitude != null && item.location?.longitude != null ? () async {
                          index.value = 1;
                          tabController.animateTo(1);
                          await completer.future;
                          final marker = markers.firstWhere((e) => e.point.latitude == item.location?.latitude && e.point.longitude == item.location?.longitude);
                          popupController.showPopupsOnlyFor([marker]);
                          mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                        } : null,
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
                                      borderRadius: const BorderRadius.all(Radius.circular(10))
                                  ),
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
                                  child: Text(
                                      "Close",
                                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
                                  ),
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
            SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Unknown Location"),
          if (withoutLocation.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    title: const Text("Devices without locations"),
                    children: withoutLocation.map((item) => ListTile(
                      mouseCursor: MouseCursor.defer,
                      title: Text(item.name ?? "Unknown Device"),
                      subtitle: Text(item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found"),
                      onTap: item.location?.latitude != null && item.location?.longitude != null ? () async {
                        index.value = 1;
                        tabController.animateTo(1);
                        await completer.future;
                        final marker = markers.firstWhere((e) => e.point.latitude == item.location?.latitude && e.point.longitude == item.location?.longitude);
                        popupController.showPopupsOnlyFor([marker]);
                        mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                      } : null,
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
                                    borderRadius: const BorderRadius.all(Radius.circular(10))
                                ),
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
                                child: Text(
                                    "Close",
                                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        );
                      },
                    )).toList()
                  ),
                ),
              ],
            ),
        ]),
      ),
    ];

    final actions = [
      if (!refreshing)
        IconButton(
          icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh, color: context.theme.colorScheme.onBackground),
          onPressed: () {
            setState(() {
              refreshing = true;
            });
            getLocations(refresh: true);
          },
        ),
      if (refreshing)
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: buildProgressIndicator(context),
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
          systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
          statusBarColor: Colors.transparent, // status bar color
          statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        ),
        child: Obx(() => Scaffold(
          backgroundColor: material ? tileColor : headerColor,
          appBar: samsung && index.value == 0
              ? null
              : PreferredSize(
            preferredSize: Size(ns.width(context), 50),
            child: AppBar(
              systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              toolbarHeight: 50,
              elevation: 0,
              scrolledUnderElevation: 3,
              surfaceTintColor: context.theme.colorScheme.primary,
              leading: buildBackButton(context),
              backgroundColor: headerColor,
              centerTitle: iOS,
              title: Text(
                "FindMy",
                style: context.theme.textTheme.titleLarge,
              ),
              actions: actions,
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: tabController,
            children: <Widget>[
              NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                  final scrollDistance = context.height / 3 - 57;

                  if (controller1.offset > 0 && controller1.offset < scrollDistance) {
                    final double snapOffset = controller1.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                    Future.microtask(() =>
                        controller1.animateTo(snapOffset, duration: const Duration(milliseconds: 200), curve: Curves.linear));
                  }
                  return false;
                },
                child: ScrollbarWrapper(
                  controller: controller1,
                  child: Obx(() => CustomScrollView(
                    controller: controller1,
                    physics: (kIsDesktop || kIsWeb)
                        ? const NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics(),
                    slivers: <Widget>[
                      if (samsung)
                        SliverAppBar(
                          backgroundColor: headerColor,
                          pinned: true,
                          stretch: true,
                          expandedHeight: context.height / 3,
                          elevation: 0,
                          automaticallyImplyLeading: false,
                          flexibleSpace: LayoutBuilder(
                            builder: (context, constraints) {
                              var expandRatio = (constraints.maxHeight - 100) / (context.height / 3 - 50);

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
                                    child: Center(child: Text("FindMy", style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
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
                                            "FindMy",
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
                        ),
                      if (ss.settings.skin.value != Skins.Samsung)
                        ...bodySlivers,
                      if (ss.settings.skin.value == Skins.Samsung)
                        SliverToBoxAdapter(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                            child: CustomScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              slivers: bodySlivers,
                            ),
                          ),
                        ),
                    ],
                  ),
                  ),
                ),
              ),
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  zoom: 5.0,
                  center: location == null ? null : LatLng(location!.latitude, location!.longitude),
                  onTap: (_, __) => popupController.hideAllPopups(), // Hide popup when the map is tapped.
                  keepAlive: true,
                  interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  onMapReady: () {
                    completer.complete();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  PopupMarkerLayerWidget(
                    options: PopupMarkerLayerOptions(
                      popupController: popupController,
                      markers: markers,
                      popupBuilder: (context, marker) {
                        final item = devices.firstWhere((e) => e.location?.latitude == marker.point.latitude && e.location?.longitude == marker.point.longitude);
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
                                Text(item.name ?? "Unknown Device", style: context.theme.textTheme.labelLarge),
                                Text(item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found", style: context.theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        );
                      },
                      markerRotateAlignment: PopupMarkerLayerOptions.rotationAlignmentFor(AnchorAlign.top),
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index.value,
            backgroundColor: headerColor,
            destinations: [
              NavigationDestination(
                icon: Icon(iOS ? CupertinoIcons.square_list : Icons.list_alt_outlined),
                label: "LIST",
              ),
              NavigationDestination(
                icon: Icon(
                  iOS
                      ? CupertinoIcons.map
                      : Icons.map_outlined,
                ),
                label: "MAP",
              ),
            ],
            onDestinationSelected: (page) {
              if (fetching != false || devices.isEmpty) return;
              index.value = page;
              tabController.animateTo(page);
            },
          ),
        ),
      ),
    );
  }
}
