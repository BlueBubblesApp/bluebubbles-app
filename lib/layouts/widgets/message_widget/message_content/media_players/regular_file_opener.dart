import 'dart:convert';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

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

    return GestureDetector(
      onTap: () async {
        if (kIsWeb || file.path == null) {
          final content = base64.encode(file.bytes!);
          html.AnchorElement(
              href: "data:application/octet-stream;charset=utf-16le;base64,$content")
            ..setAttribute("download", file.name)
            ..click();
        } else {
          if (kIsDesktop) {
            String? savePath = await FilePicker.platform.saveFile(
              initialDirectory: (await getDownloadsDirectory())?.path,
              dialogTitle: 'Choose a location to save this file',
              fileName: file.name,
            );
            Logger.info(savePath);
            if (savePath != null) {
              File(file.path!).copy(savePath);
              return showSnackbar('Success', 'Saved attachment to $savePath!');
            }
            return;
          }
          try {
            await MethodChannelInterface().invokeMethod(
              "open_file",
              {
                "path": "/attachments/" +
                    attachment.guid! +
                    "/" +
                    basename(file.path!),
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
        color: Theme.of(context).colorScheme.secondary,
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
                style: Theme.of(context).textTheme.bodyText2,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  fileIcon,
                  color: Theme.of(context).textTheme.bodyText2!.color,
                ),
              ),
              Text(
                attachment.mimeType!,
                style: Theme.of(context).textTheme.bodyText2,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
