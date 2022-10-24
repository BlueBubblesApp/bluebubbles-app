import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttachmentDownloaderWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        placeHolder,
        CupertinoButton(
          padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
          onPressed: onPressed,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                attachment.getFriendlySize(),
                style: context.theme.textTheme.bodyMedium,
              ),
              SizedBox(height: 5),
              Icon(ss.settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.cloud_download, size: 28.0),
              SizedBox(height: 5),
              (attachment.mimeType != null)
                  ? Text(
                      attachment.mimeType!,
                      style: context.theme.textTheme.bodyLarge,
                    )
                  : Container()
            ],
          ),
        ),
      ],
    );
  }
}
