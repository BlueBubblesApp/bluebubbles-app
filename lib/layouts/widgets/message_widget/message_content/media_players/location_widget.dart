import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class LocationWidget extends StatefulWidget {
  LocationWidget({
    Key key,
    this.file,
    this.attachment,
  }) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _LocationWidgetState createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<LocationWidget> {
  Map<String, dynamic> location;
  @override
  void initState() {
    super.initState();
    String _location = widget.file.readAsStringSync();
    location = AttachmentHelper.parseAppleLocation(_location);
  }

  @override
  Widget build(BuildContext context) {
    if (location["longitude"] != null &&
        location["longitude"].abs() < 90 &&
        location["latitude"] != null) {
      return SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            center: LatLng(location["longitude"], location["latitude"]),
            zoom: 14.0,
          ),
          layers: [
            new TileLayerOptions(
              urlTemplate:
                  "http://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
              subdomains: ['0', '1', '2', '3'],
              tileSize: 256,
            ),
            new MarkerLayerOptions(
              markers: [
                new Marker(
                  width: 40.0,
                  height: 40.0,
                  point:
                      new LatLng(location["longitude"], location["latitude"]),
                  builder: (ctx) => new Container(
                    child: new FlutterLogo(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        child: Text(
          "Could not load location",
          style: Theme.of(context).textTheme.bodyText1,
        ),
      );
    }
  }
}
