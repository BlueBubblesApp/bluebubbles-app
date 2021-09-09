import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttachmentDownloaderWidget extends StatefulWidget {
  AttachmentDownloaderWidget({
    Key? key,
    required this.placeHolder,
    required this.onPressed,
    required this.attachment,
  }) : super(key: key);
  final Widget placeHolder;
  final Function() onPressed;
  final Attachment attachment;

  @override
  _AttachmentDownloaderWidgetState createState() => _AttachmentDownloaderWidgetState();
}

class _AttachmentDownloaderWidgetState extends State<AttachmentDownloaderWidget> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        widget.placeHolder,
        CupertinoButton(
          padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
          onPressed: widget.onPressed,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.attachment.getFriendlySize(),
                style: Theme.of(context).textTheme.bodyText1,
              ),
              Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.cloud_download, size: 28.0),
              (widget.attachment.mimeType != null)
                  ? Text(
                      widget.attachment.mimeType!,
                      style: Theme.of(context).textTheme.bodyText1,
                    )
                  : Container()
            ],
          ),
        ),
      ],
    );
  }
}
