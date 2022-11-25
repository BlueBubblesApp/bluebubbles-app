import 'dart:convert';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
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
        if (attachment.mimeStart == "image" || (attachment.mimeStart == "video" && !kIsDesktop)) {
          Navigator.of(Get.context!).push(
            ThemeSwitcher.buildPageRoute(
              builder: (context) => FullscreenMediaHolder(
                currentChat: cm.activeChat,
                attachment: attachment,
                showInteractions: true,
              ),
            ),
          );
          return;
        }
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
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              getAttachmentIcon(attachment.mimeType ?? ""),
              color: context.theme.colorScheme.properOnSurface,
              size: 35,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                  ),
                  const SizedBox(height: 2.5),
                  Text(
                    "${(mime(file.name)?.split("/").lastOrNull ?? mime(file.name) ?? "file").toUpperCase()} • ${file.size.toDouble().getFriendlySize()}",
                    style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}