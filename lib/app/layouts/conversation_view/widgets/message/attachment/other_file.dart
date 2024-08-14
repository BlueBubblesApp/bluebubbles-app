import 'dart:convert';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class OtherFile extends StatelessWidget {
  OtherFile({
    super.key,
    required this.attachment,
    required this.file,
  });
  final Attachment attachment;
  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (attachment.mimeStart == "image" || (attachment.mimeStart == "video" && !isSnap)) {
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
          File _file = File(join((await getTemporaryDirectory()).path, "BlueBubbles", "attachments", attachment.guid, basename(file.path!)));
          if (!_file.existsSync()) {
            _file.createSync(recursive: true);
            File(file.path!).copySync(_file.path);
          }
          launchUrl(Uri.file(_file.path));
        } else {
          try {
            final res = await OpenFilex.open("${fs.appDocDir.path}/attachments/${attachment.guid!}/${basename(file.path!)}");
            if (res.type == ResultType.noAppToOpen) {
              showSnackbar('Error', "No handler for this file type! Using share menu instead.");
              await Future.delayed(const Duration(seconds: 1));
              Share.file(file.name, file.path!);
            } else if (res.type == ResultType.error) {
              showSnackbar('Error', res.message);
            } else if (res.type == ResultType.fileNotFound) {
              showSnackbar('Not Found', "File not found at path: ${file.path}");
            } else if (res.type == ResultType.permissionDenied) {
              showSnackbar('Permission Denied', "BlueBubbles does not have access to this file! Using share menu instead.");
              await Future.delayed(const Duration(seconds: 1));
              Share.file(file.name, file.path!);
            }
          } catch (ex) {
            Logger.error("Error opening file: ${file.path}", error: ex);
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
