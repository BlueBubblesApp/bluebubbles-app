import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:get/get.dart';
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

  final RxBool dragging = false.obs;

  final RxInt numFiles = 0.obs;

  DropZoneManager({required this.controller});

  void onDropOver(DropEventDetails event) {
    dragging.value = true;
  }

  void onDropLeave(DropEventDetails event) {
    dragging.value = false;
  }

  Future<void> onPerformDrop(
    DropDoneDetails event,
    ConversationViewController controller,
  ) async {
    for (DropItem item in event.files) {
      if (await FileSystemEntity.type(item.path) != FileSystemEntityType.file) continue;

      String fileName = item.name;

      if (fileName.isEmpty) {
        fileName = "Dragged_File_${controller.pickedAttachments.length + 1}";
      }

      controller.pickedAttachments.add(PlatformFile(
        name: fileName,
        path: item.path,
        size: await item.length(),
        bytes: null,
      ));
    }

    dragging.value = false;
  }
}
