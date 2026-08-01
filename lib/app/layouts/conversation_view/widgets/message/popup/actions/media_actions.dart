import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_action_context.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' hide context;
import 'package:url_launcher/url_launcher_string.dart';

Future<void> downloadAttachment(MessagePopupActionContext ctx) async {
  try {
    dynamic content;
    if (ctx.isEmbeddedMedia) {
      content = PlatformFile(
        name: basename(ctx.message.interactiveMediaPath!),
        path: ctx.message.interactiveMediaPath,
        size: 0,
      );
    } else {
      content = AttachmentsSvc.getContent(ctx.part.attachments.first);
    }

    if (content is PlatformFile) {
      ctx.popDetails();
      await AttachmentsSvc.saveToDisk(
        content,
        isDocument: ctx.part.attachments.first.mimeStart != "image" && ctx.part.attachments.first.mimeStart != "video",
      );
    }
  } catch (ex, trace) {
    Logger.error("Error downloading attachment: ${ex.toString()}", error: ex, trace: trace);
    ctx.showSnack("Save Error", ex.toString());
  }
}

Future<void> openAttachmentWeb(MessagePopupActionContext ctx) async {
  await launchUrlString("${ctx.part.attachments.first.webUrl!}?guid=${SettingsSvc.settings.guidAuthKey}");
  ctx.popDetails();
}

Future<void> openInImageViewer(MessagePopupActionContext ctx) async {
  try {
    final content = AttachmentsSvc.getContent(ctx.part.attachments.first);
    if (content is! PlatformFile || isNullOrEmptyString(content.path)) {
      ctx.showSnack("Open Error", "Failed to find image file path!");
      return;
    }

    final response = await OpenFilex.open(content.path!, type: ctx.part.attachments.first.mimeType);
    if (response.type == ResultType.done) {
      ctx.popDetails();
      return;
    }

    if (response.type == ResultType.noAppToOpen) {
      ctx.showSnack("Open Error", "No app found to open this image!");
      return;
    }

    Logger.warn(
      "Failed to open image in viewer (${response.type}): ${response.message}",
      tag: "MessagePopup",
    );
    ctx.showSnack("Open Error", response.message);
  } catch (ex, trace) {
    Logger.error("Failed to open image in viewer!", error: ex, trace: trace);
    ctx.showSnack("Open Error", "Failed to open image!");
  }
}

void copyAttachment(MessagePopupActionContext ctx) {
  if (ctx.part.attachments.length == 1) {
    Pasteboard.writeFiles([ctx.part.attachments.first.path]).then((_) {
      ctx.popDetails();
    }).catchError((e) {
      Logger.error("Failed to copy files!", error: e);
      ctx.showSnack("Copy Error", "Failed to copy image!");
    });
    return;
  }

  Pasteboard.writeFiles(ctx.part.attachments.map((element) => element.path).toList()).then((_) {
    ctx.popDetails();
  }).catchError((e) {
    Logger.error("Failed to copy attachment(s)!", error: e);
    ctx.showSnack("Copy Error", "Failed to copy attachment(s)!");
  });
}

Future<void> downloadOriginalAttachments(MessagePopupActionContext ctx) async {
  final RxBool downloadingAttachments = true.obs;
  final RxnDouble progress = RxnDouble();
  final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
  final toDownload = ctx.part.attachments.where((element) =>
      (element.uti?.contains("heic") ?? false) ||
      (element.uti?.contains("heif") ?? false) ||
      (element.uti?.contains("quicktime") ?? false) ||
      (element.uti?.contains("coreaudio") ?? false) ||
      (element.uti?.contains("tiff") ?? false));
  final length = toDownload.length;

  showBBDialog(
    context: ctx.context,
    title: "Downloading attachment${length > 1 ? "s" : ""}...",
    content: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Obx(
          () => Text(
            '${progress.value != null && attachmentObs.value != null ? (progress.value! * attachmentObs.value!.totalBytes!).getFriendlySize() : ""} / ${(attachmentObs.value!.totalBytes!.toDouble()).getFriendlySize()} (${((progress.value ?? 0) * 100).floor()}%)',
            style: Theme.of(ctx.context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 10.0),
        Obx(
          () => ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              backgroundColor: Theme.of(ctx.context).colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(ctx.context).colorScheme.primary),
              value: progress.value,
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(height: 15.0),
        Obx(() => Text(
              progress.value == 1
                  ? "Download Complete!"
                  : "You can close this dialog. The attachment(s) will continue to download in the background.",
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(ctx.context).textTheme.bodyLarge,
            )),
      ],
    ),
    actions: [
      BBDialogAction(
        text: "Close",
        onPressed: () async {
          Get.closeAllSnackbars();
          Navigator.of(ctx.context, rootNavigator: true).pop();
          ctx.popDetails();
        },
      ),
    ],
  );

  try {
    for (final Attachment? element in toDownload) {
      attachmentObs.value = element;
      final response = await HttpSvc.attachment.download(
        element!.guid!,
        original: true,
        onReceiveProgress: (count, total) {
          progress.value = kIsWeb ? (count / total) : (count / element.totalBytes!);
        },
      );
      final file = PlatformFile(
        name: element.transferName!,
        size: response.data.length,
        bytes: response.data,
      );

      await AttachmentsSvc.saveToDisk(file, isDocument: element.mimeStart != "image" && element.mimeStart != "video");
    }
    progress.value = 1;
    downloadingAttachments.value = false;
  } catch (ex, trace) {
    Logger.error("Failed to download original attachment!", error: ex, trace: trace);
    ctx.showSnack("Download Error", ex.toString());
  }
}

Future<void> downloadLivePhoto(MessagePopupActionContext ctx) async {
  final RxBool downloadingAttachments = true.obs;
  final RxnInt progress = RxnInt();
  final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
  final toDownload = ctx.part.attachments.where((element) => element.hasLivePhoto);
  final length = toDownload.length;

  showBBDialog(
    context: ctx.context,
    title: "Downloading live photo${length > 1 ? "s" : ""}...",
    content: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Obx(() =>
            Text(progress.value?.toDouble().getFriendlySize() ?? "", style: Theme.of(ctx.context).textTheme.bodyLarge)),
        const SizedBox(height: 10.0),
        Obx(
          () => ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              backgroundColor: Theme.of(ctx.context).colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(ctx.context).colorScheme.primary),
              value: downloadingAttachments.value ? null : 1,
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(height: 15.0),
        Obx(() => Text(
              !downloadingAttachments.value
                  ? "Download Complete!"
                  : "You can close this dialog. The live photo(s) will continue to download in the background.",
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(ctx.context).textTheme.bodyLarge,
            )),
      ],
    ),
    actions: [
      BBDialogAction(
        text: "Close",
        onPressed: () async {
          Get.closeAllSnackbars();
          Navigator.of(ctx.context, rootNavigator: true).pop();
          ctx.popDetails();
        },
      ),
    ],
  );

  try {
    for (final Attachment? element in toDownload) {
      attachmentObs.value = element;
      final response = await HttpSvc.attachment
          .downloadLivePhoto(element!.guid!, onReceiveProgress: (count, total) => progress.value = count);
      final nameSplit = element.transferName!.split(".");
      final file = PlatformFile(
        name: "${nameSplit.take(nameSplit.length - 1).join(".")}.mov",
        size: response.data.length,
        bytes: response.data,
      );
      await AttachmentsSvc.saveToDisk(file, isDocument: true);
    }
    downloadingAttachments.value = false;
  } catch (ex, trace) {
    Logger.error("Failed to download live photo!", error: ex, trace: trace);
    ctx.showSnack("Download Error", ex.toString());
  }
}

void redownload(MessagePopupActionContext ctx) {
  if (ctx.isEmbeddedMedia) {
    ctx.popDetails();
    ctx.service.getMessageStateIfExists(ctx.message.guid!)?.embeddedMediaRefreshKey.value++;
    return;
  }

  final msgGuid = ctx.message.guid;
  if (msgGuid != null) {
    for (final Attachment? element in ctx.part.attachments) {
      if (element != null) {
        unawaited(ctx.service.redownloadAttachment(msgGuid, element));
      }
    }
  }
  ctx.popDetails();
}

/// Clears any cached web-loaded preview state (URL previews, Photos app
/// previews, etc) for this message and signals its interactive widget to
/// re-fetch. Generic across preview types - the widget itself (via
/// [MessageState.previewRefreshKey]) owns how it re-fetches its own content.
void refreshPreview(MessagePopupActionContext ctx) {
  if (ctx.message.metadata != null) {
    ctx.message.metadata = null;
    ctx.message.save();
  }
  // The persisted copy is only half the cache — drop the in-memory entry too,
  // or the refetch is served from it and nothing appears to change.
  MetadataHelper.invalidateForMessage(ctx.message);
  ctx.messageState.previewRefreshKey.value++;
  ctx.popDetails();
}

void sharePart(MessagePopupActionContext ctx) {
  if (ctx.part.attachments.isNotEmpty && !ctx.message.isLegacyUrlPreview && !kIsWeb && !kIsDesktop) {
    Share.files(ctx.part.attachments.map((a) => a.path).nonNulls.toList());
  } else if (ctx.part.text!.isNotEmpty) {
    Share.text(ctx.part.text!);
  }
  ctx.popDetails();
}
