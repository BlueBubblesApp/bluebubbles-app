import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/widgets/circle_progress_bar.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class MediaFile extends StatefulWidget {
  MediaFile({
    Key? key,
    required this.child,
    required this.attachment,
  }) : super(key: key);
  final Widget child;
  final Attachment attachment;

  @override
  _MediaFileState createState() => _MediaFileState();
}

class _MediaFileState extends State<MediaFile> {
  @override
  void initState() {
    super.initState();
    SocketManager().attachmentSenderCompleter.listen((event) {
      if (event == widget.attachment.guid && mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAttachments = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;

    if (SocketManager().attachmentSenders.containsKey(widget.attachment.guid)) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          widget.child,
          Obx(() {
            Tuple2<num?, bool> data = SocketManager().attachmentSenders[widget.attachment.guid]!.attachmentData.value;
            if (data.item2) {
              return Text(
                "Unable to send",
                style: Theme.of(context).textTheme.bodyText1,
              );
            }

            return Container(
                height: 40,
                width: 40,
                child: CircleProgressBar(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey,
                    value: data.item1?.toDouble() ?? 0));
          }),
        ],
      );
    } else {
      return Stack(alignment: Alignment.center, children: [
        widget.child,
        if (widget.attachment.originalROWID == null)
          Container(
            child: SettingsManager().settings.skin.value == Skins.iOS ? Theme(
              data: ThemeData(
                cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark),
              ),
              child: CupertinoActivityIndicator(
                radius: 10,
              ),
            ) : Container(height: 20, width: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2,))),
            height: 45,
            width: 45,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)), color: Colors.black.withOpacity(0.5)),
          ),
        if (hideAttachments)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        if (hideAttachments && !hideAttachmentTypes)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                widget.attachment.mimeType!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ]);
    }
  }
}
