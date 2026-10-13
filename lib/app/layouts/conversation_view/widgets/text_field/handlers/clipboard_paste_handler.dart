import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' hide context;
import 'package:universal_io/io.dart';

/// Handles clipboard paste operations (Ctrl+V or Cmd+V) on desktop.
class ClipboardPasteHandler {
  final ConversationViewController controller;

  ClipboardPasteHandler({
    required this.controller,
  });

  /// Handle Ctrl+V (or Cmd+V) paste key event.
  /// Returns true if the event was handled.
  Future<bool> handlePasteEvent() async {
    try {
      // Try to get GIF URL from clipboard HTML
      final html = await Pasteboard.html;
      if (html != null) {
        final gifMatch = RegExp(r'src="(https?://[^"]+\.gif)"').firstMatch(html);
        if (gifMatch != null) {
          final url = gifMatch.group(1)!;
          final response = await GetIt.I<HttpService>().dio.get<List<int>>(
                url,
                options: Options(responseType: ResponseType.bytes),
              );
          final bytes = response.data;
          if (bytes != null && bytes.isNotEmpty) {
            final gifBytes = Uint8List.fromList(bytes);
            controller.pickedAttachments.add(PlatformFile(
              name: "gif-${controller.pickedAttachments.length + 1}.gif",
              bytes: gifBytes,
              size: gifBytes.length,
            ));
            return true;
          }
        }
      }

      // Try to get files
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (final String path in files) {
          final String name = basename(path);
          final File file = File(path);
          controller.pickedAttachments.add(PlatformFile(
            name: name,
            path: path,
            bytes: await file.readAsBytes(),
            size: await file.length(),
          ));
        }
        return true;
      }

      // Try to get image from clipboard
      final image = await Pasteboard.image;
      if (image != null) {
        controller.pickedAttachments.add(PlatformFile(
          name: "image-${controller.pickedAttachments.length + 1}.png",
          bytes: image,
          size: image.length,
        ));
        return true;
      }

      // Fallback to text paste for platforms where we intercept Ctrl+V ourselves
      // and therefore must handle text insertion manually (Windows and Linux).
      final data = await Clipboard.getData('text/plain');
      if (data?.text != null) {
        final tc = controller.textController;
        final sel = tc.selection;
        final newText = tc.text.replaceRange(sel.start, sel.end, data!.text!);
        tc.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: sel.start + data.text!.length),
        );
        return true;
      }
      return false;
    } catch (e) {
      // Silently fail and let OS handle text paste
      return false;
    }
  }

  /// Handle content insertion from keyboard (e.g., pasted images on mobile).
  /// This is called via ContentInsertionConfiguration.onContentInserted.
  void handleKeyboardInsertedContent(KeyboardInsertedContent content) async {
    // Parse filename from URI
    String filename = FilesystemSvc.uriToFilename(content.uri, content.mimeType);

    // Save data to attachments if available
    if (content.hasData) {
      controller.pickedAttachments.add(PlatformFile(
        name: filename,
        size: content.data!.length,
        bytes: content.data,
      ));
    }
  }
}
