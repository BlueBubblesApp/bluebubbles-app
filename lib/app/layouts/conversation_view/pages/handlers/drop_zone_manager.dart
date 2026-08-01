import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' hide context;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:universal_io/io.dart';

/// Manages drag-and-drop file operations on the message list.
///
/// Responsibilities:
/// - Track drag state (files over the drop zone)
/// - Validate dropped files
/// - Convert dropped files to PlatformFile objects
/// - Add files to the attachment picker
class DropZoneManager {
  final ConversationViewController controller;

  /// Whether files are currently being dragged over the drop zone
  final RxBool dragging = false.obs;

  /// Number of valid files in the current drag session
  final RxInt numFiles = 0.obs;

  DropZoneManager({required this.controller});

  /// Check if drop is allowed (any copy operation carrying files)
  DropOperation onDropOver(DropOverEvent event) {
    if (!event.session.allowedOperations.contains(DropOperation.copy)) {
      dragging.value = false;
      return DropOperation.forbidden;
    }

    numFiles.value = event.session.items
        .where((item) =>
            item.canProvide(Formats.fileUri) ||
            Formats.standardFormats.whereType<FileFormat>().any((f) => item.canProvide(f)))
        .length;

    if (numFiles.value == 0) {
      dragging.value = false;
      return DropOperation.forbidden;
    }

    dragging.value = true;
    return DropOperation.copy;
  }

  /// Handle drag leaving the drop zone
  void onDropLeave(DropEvent event) {
    dragging.value = false;
  }

  /// Process dropped files and add them to attachments.
  ///
  /// Awaits all reader callbacks before returning so the native drop session
  /// stays alive until data has been fully read.
  Future<void> onPerformDrop(
    PerformDropEvent event,
    ConversationViewController controller,
  ) async {
    final reads = <Future<void>>[];

    for (DropItem item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      FileFormat? format = reader.getFormats(Formats.standardFormats).whereType<FileFormat>().firstOrNull;

      // getFile/getValue deliver data via callback; track each read with a
      // completer so the drop session isn't torn down before the data arrives.
      final completer = Completer<void>();

      if (format != null) {
        reads.add(completer.future);
        reader.getFile(format, (file) async {
          try {
            Uint8List bytes = await file.readAll();
            String fileName = file.fileName ?? "";

            // On Linux, the file path is encoded as UTF-8 bytes
            if (Platform.isLinux) {
              final filePath = String.fromCharCodes(bytes);
              File linuxFile = File(filePath);
              bytes = await linuxFile.readAsBytes();
              fileName = basename(filePath);
            }

            if (fileName.isEmpty) {
              fileName = "Dragged_File_${controller.pickedAttachments.length + 1}";
            }

            controller.pickedAttachments.add(PlatformFile(
              name: fileName,
              size: bytes.length,
              bytes: bytes,
            ));
          } finally {
            completer.complete();
          }
        }, onError: (_) => completer.complete());
      } else if (reader.canProvide(Formats.fileUri)) {
        // No standard format matched (arbitrary file type) — read straight
        // from the dropped file's path instead.
        reads.add(completer.future);
        reader.getValue(Formats.fileUri, (uri) async {
          try {
            if (uri == null) return;
            final file = File(uri.toFilePath());
            if (!await file.exists()) return;

            final bytes = await file.readAsBytes();
            controller.pickedAttachments.add(PlatformFile(
              name: basename(file.path),
              size: bytes.length,
              bytes: bytes,
            ));
          } finally {
            completer.complete();
          }
        }, onError: (_) => completer.complete());
      }
    }

    await Future.wait(reads);
    dragging.value = false;
  }
}
