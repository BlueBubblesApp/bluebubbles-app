import 'dart:convert';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

class RegularFileOpener extends StatelessWidget {
  RegularFileOpener({
    Key? key,
    required this.attachment,
    required this.file,
  }) : super(key: key);
  final Attachment attachment;
  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    IconData fileIcon = AttachmentHelper.getIcon(attachment.mimeType ?? "");

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: () async {
        if (kIsWeb || file.path == null) {
          final content = base64.encode(file.bytes!);
          html.AnchorElement(
              href: "data:application/octet-stream;charset=utf-16le;base64,$content")
            ..setAttribute("download", file.name)
            ..click();
        } else {
          if (kIsDesktop) {
            launchUrl(Uri.file(file.path!));
            return;
          }
          try {
            await MethodChannelInterface().invokeMethod(
              "open_file",
              {
                "path": "/attachments/${attachment.guid!}/${basename(file.path!)}",
                "mimeType": attachment.mimeType,
              },
            );
          } catch (ex) {
            showSnackbar('Error', "No handler for this file type!");
          }
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 140,
          maxWidth: 200,
        ),
        color: context.theme.colorScheme.properSurface,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                file.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodyMedium,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  fileIcon,
                  color: context.theme.colorScheme.properOnSurface,
                ),
              ),
              Text(
                attachment.mimeType!,
                style: context.theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
