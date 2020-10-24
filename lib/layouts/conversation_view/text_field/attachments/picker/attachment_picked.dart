import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class AttachmentPicked extends StatefulWidget {
  AttachmentPicked({Key key, @required this.onTap, @required this.data})
      : super(key: key);
  final AssetEntity data;
  final Function onTap;

  @override
  _AttachmentPickedState createState() => _AttachmentPickedState();
}

class _AttachmentPickedState extends State<AttachmentPicked> {
  Uint8List image;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    image = await widget.data.thumbDataWithSize(800, 800, quality: 20);
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return image != null
        ? Stack(
            alignment: Alignment.bottomRight,
            children: <Widget>[
              Image.memory(
                image,
                fit: BoxFit.cover,
                width: 150,
                height: 150,
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    child: widget.data.type == AssetType.video
                        ? Icon(
                            Icons.play_circle_filled,
                            color: Colors.white.withOpacity(0.5),
                            size: 50,
                          )
                        : Container(),
                    onTap: () async {
                      widget.onTap();
                    },
                  ),
                ),
              ),
            ],
          )
        : SizedBox(
            width: 100,
            height: 100,
          );
  }
}
