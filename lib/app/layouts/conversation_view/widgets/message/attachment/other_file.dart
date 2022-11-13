import 'dart:convert';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class OtherFile extends StatelessWidget {
  OtherFile({
    Key? key,
    required this.attachment,
    required this.file,
  }) : super(key: key);
  final Attachment attachment;
  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (kIsWeb || file.path == null) {
          final content = base64.encode(file.bytes!);
          html.AnchorElement(
              href: "data:application/octet-stream;charset=utf-16le;base64,$content")
            ..setAttribute("download", file.name)
            ..click();
        } else if (kIsDesktop) {
          String? savePath = await FilePicker.platform.saveFile(
            initialDirectory: (await getDownloadsDirectory())?.path,
            dialogTitle: 'Choose a location to save this file',
            fileName: file.name,
          );
          Logger.info(savePath);
          if (savePath != null) {
            if (await File(savePath).exists()) {
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Confirm save",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: Text("This file already exists.\nAre you sure you want to overwrite it?", style: context.theme.textTheme.bodyLarge),
                    backgroundColor: context.theme.colorScheme.properSurface,
                    actions: <Widget>[
                      TextButton(
                        child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await File(file.path!).copy(savePath);
                          showSnackbar('Success', 'Saved attachment to $savePath!');
                        },
                      ),
                    ],
                  );
                },
              );
            } else {
              await File(file.path!).copy(savePath);
              showSnackbar('Success', 'Saved attachment to $savePath!');
            }
          }
        } else {
          try {
            await mcs.invokeMethod(
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
      child: SizedBox(
        height: 150,
        width: 200,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  getAttachmentIcon(attachment.mimeType ?? ""),
                  color: context.theme.colorScheme.properOnSurface,
                ),
              ),
              Text(
                file.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
