import 'dart:convert';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:universal_io/io.dart';

class LocationWidget extends StatefulWidget {
  LocationWidget({
    Key? key,
    required this.file,
    this.showOpen = true
  }) : super(key: key);
  final PlatformFile file;
  final bool showOpen;

  @override
  State<LocationWidget> createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<LocationWidget> {
  AppleLocation? location;

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  void loadLocation() async {
    // If we already have location data, don't load it again
    if (location != null) return;
    String _location;

    if (kIsWeb || widget.file.path == null) {
      _location = utf8.decode(widget.file.bytes!);
    } else {
      _location = await File(widget.file.path!).readAsString();
    }
    location = AttachmentHelper.parseAppleLocation(_location);

    if (location != null && mounted) {
      setState(() {});
    }
  }

  void openMaps() async {
    if (location == null) return;

    await MapsLauncher.launchCoordinates(location!.longitude!, location!.latitude!);
  }

  @override
  Widget build(BuildContext context) {
    if (location != null &&
        location!.longitude != null &&
        location!.longitude!.abs() < 90 &&
        location!.latitude != null) {
      return GestureDetector(
          onTap: openMaps,
          child: Container(
              height: 240,
              color: context.theme.colorScheme.properSurface,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        height: widget.showOpen ? 200 : 240,
                        child: FlutterMap(
                          options: MapOptions(
                            center: LatLng(location!.longitude!, location!.latitude!),
                            zoom: 14.0,
                          ),
                          layers: [
                            TileLayerOptions(
                              urlTemplate: "http://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
                              subdomains: ['0', '1', '2', '3'],
                              tileSize: 256,
                            ),
                            MarkerLayerOptions(
                              markers: [
                                Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: LatLng(location!.longitude!, location!.latitude!),
                                  anchorPos: AnchorPos.align(AnchorAlign.top),
                                  builder: (ctx) => Container(
                                    child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.location_solid : Icons.location_on, color: Colors.red, size: 40),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )),
                    if (widget.showOpen)
                      InkWell(
                          onTap: openMaps,
                          child: Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 10),
                              child: Text("Open in Maps", style: context.theme.textTheme.bodyMedium)))
                  ])));
    } else {
      return Container(
        padding: EdgeInsets.all(10),
        child: Text(
          "Could not load location",
          style: context.theme.textTheme.bodyMedium,
        ),
      );
    }
  }
}
