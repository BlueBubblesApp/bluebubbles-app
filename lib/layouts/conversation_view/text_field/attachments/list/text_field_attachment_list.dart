import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime_type/mime_type.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class TextFieldAttachmentList extends StatefulWidget {
  TextFieldAttachmentList({Key key, this.attachments}) : super(key: key);
  final List<File> attachments;

  @override
  _TextFieldAttachmentListState createState() =>
      _TextFieldAttachmentListState();
}

class _TextFieldAttachmentListState extends State<TextFieldAttachmentList>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      vsync: this,
      duration: Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.attachments.length > 0 ? 100 : 0,
        ),
        child: GridView.builder(
          itemCount: widget.attachments.length,
          scrollDirection: Axis.horizontal,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
          ),
          itemBuilder: (context, int index) {
            return Stack(
              children: <Widget>[
                mime(widget.attachments[index].path).startsWith("video/")
                    ? FutureBuilder(
                        future: VideoThumbnail.thumbnailData(
                          video: widget.attachments[index].path,
                          imageFormat: ImageFormat.PNG,
                          maxHeight: 100,
                          quality: 25,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            return Image.memory(snapshot.data,
                                fit: BoxFit.fill);
                          }
                          return SizedBox(
                            height: 100,
                            width: 100,
                            child: CircularProgressIndicator(),
                          );
                        },
                      )
                    : Hero(
                        tag: widget.attachments[index].path,
                        child: FutureBuilder<Uint8List>(
                          future: FlutterImageCompress.compressWithFile(
                              widget.attachments[index].absolute.path,
                              quality: SettingsManager().settings.lowMemoryMode
                                  ? 5
                                  : 10 // This is arbitrary
                              ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data,
                                height: 100,
                                fit: BoxFit.fitHeight,
                              );
                            }
                            return Container(
                              height: 100,
                              child: Center(
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.grey,
                                  valueColor: AlwaysStoppedAnimation(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                mime(widget.attachments[index].path).startsWith("video/")
                    ? Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                        ),
                      )
                    : Container(),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(80),
                      color: Colors.black,
                    ),
                    width: 25,
                    height: 25,
                    child: GestureDetector(
                      onTap: () {
                        File image = widget.attachments[index];
                        for (int i = 0; i < widget.attachments.length; i++) {
                          if (widget.attachments[i].path == image.path) {
                            widget.attachments.removeAt(i);
                            setState(() {});
                            return;
                          }
                        }
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
