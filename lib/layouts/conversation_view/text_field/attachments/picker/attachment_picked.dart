import 'dart:typed_data';

import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class AttachmentPicked extends StatefulWidget {
  AttachmentPicked({Key key, @required this.onTap, @required this.data}) : super(key: key);
  final AssetEntity data;
  final Function onTap;

  @override
  _AttachmentPickedState createState() => _AttachmentPickedState();
}

class _AttachmentPickedState extends State<AttachmentPicked> with AutomaticKeepAliveClientMixin {
  Uint8List image;
  String path;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    path = (await widget.data.file).path;
    BlueBubblesTextField.of(context).stream.listen((event) {
      if (this.mounted) setState(() {});
    });
  }

  Future<void> load() async {
    image = await widget.data.thumbDataWithSize(800, 800, quality: 20);
    if (this.mounted) setState(() {});
  }

  bool get containsThis =>
      BlueBubblesTextField.of(context).pickedImages.where((element) => element.path == path).length > 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return image != null
        ? AnimatedContainer(
            duration: Duration(milliseconds: 250),
            padding: EdgeInsets.all(containsThis ? 20 : 5),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    image,
                    fit: BoxFit.cover,
                    width: 150,
                    height: 150,
                  ),
                ),
                if (containsThis)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      child: Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                      ),
                      color: Colors.white.withAlpha(50),
                    ),
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
            ),
          )
        : SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                backgroundColor: Theme.of(context).backgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
          );
  }

  @override
  bool get wantKeepAlive => true;
}
