import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';

/// Optimized attachment picker file that uses File-based rendering instead of loading bytes
/// This significantly reduces memory usage and improves scrolling performance
class AttachmentPickerFile extends StatefulWidget {
  const AttachmentPickerFile({
    super.key,
    required this.onTap,
    required this.data,
    required this.controller,
  });

  final AssetEntity data;
  final Function() onTap;
  final ConversationViewController controller;

  @override
  State<AttachmentPickerFile> createState() => _AttachmentPickerFileState();
}

class _AttachmentPickerFileState extends State<AttachmentPickerFile> with ThemeHelpers {
  String? filePath;
  Uint8List? thumbnailBytes; // Only for videos and special formats
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    loadFilePath();
  }

  Future<void> loadFilePath() async {
    try {
      final file = await widget.data.file;
      if (file == null) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
        return;
      }

      // Only load bytes for videos (thumbnails only)
      if (widget.data.mimeType?.startsWith("video/") ?? false) {
        try {
          thumbnailBytes = await AttachmentsSvc.getVideoThumbnail(file.path, useCachedFile: false);
        } catch (ex) {
          // Leave thumbnailBytes null — _buildImage() falls back to Image.file(filePath),
          // whose errorBuilder shows the themed placeholder since a raw video file won't decode.
        }
        filePath = file.path;
      } else if (widget.data.mimeType == "image/heic" ||
          widget.data.mimeType == "image/heif" ||
          widget.data.mimeType == "image/tif" ||
          widget.data.mimeType == "image/tiff") {
        // For incompatible formats, use ensureImageCompatibility to get converted path
        // This returns a file path (not bytes), which we can render with Image.file
        final fakeAttachment = Attachment(
          transferName: file.path,
          mimeType: widget.data.mimeType!,
        );
        filePath = await AttachmentsSvc.ensureImageCompatibility(fakeAttachment, actualPath: file.path);
      } else {
        // For regular images, just use the file path directly
        filePath = file.path;
      }
      // All paths use Image.file for efficient rendering

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideAttachments = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideAttachments.value;
      bool containsThis = widget.controller.pickedAttachments.firstWhereOrNull((e) => e.path == filePath) != null;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.all(containsThis ? 10 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Show image/thumbnail
              if (!isLoading && !hasError && !hideAttachments) _buildImage(),

              // Show placeholder while loading or on error
              if (isLoading || hasError || hideAttachments) _buildPlaceholder(context),

              // Show selection indicator or video icon
              if (containsThis || widget.data.type == AssetType.video) _buildOverlayIcon(context, containsThis),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildImage() {
    // Use memory image only for videos and incompatible formats
    if (thumbnailBytes != null) {
      return Positioned.fill(
        child: Image.memory(
          thumbnailBytes!,
          fit: BoxFit.cover,
          cacheWidth: (150 * MediaQuery.of(context).devicePixelRatio).toInt(),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame == null) {
              return _buildPlaceholderContent(context);
            }
            return child;
          },
        ),
      );
    }

    if (filePath != null) {
      return Positioned.fill(
        child: Image.file(
          File(filePath!),
          fit: BoxFit.cover,
          cacheWidth: (150 * MediaQuery.of(context).devicePixelRatio).toInt(),
          filterQuality: FilterQuality.low, // Low quality is fine for thumbnails
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame == null) {
              return _buildPlaceholderContent(context);
            }
            return child;
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderContent(context);
          },
        ),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Positioned.fill(
      child: _buildPlaceholderContent(context),
    );
  }

  Widget _buildPlaceholderContent(BuildContext context) {
    return Container(
      color: context.theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: isLoading
          ? const CupertinoActivityIndicator()
          : Text(
              mime(filePath) ?? "",
              textAlign: TextAlign.center,
            ),
    );
  }

  Widget _buildOverlayIcon(BuildContext context, bool containsThis) {
    return Container(
      decoration: containsThis
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: context.theme.colorScheme.primary,
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Icon(
          containsThis
              ? (SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.check_mark : Icons.check)
              : (SettingsSvc.settings.skin.value == Skins.iOS
                  ? CupertinoIcons.play_circle_fill
                  : Icons.play_circle_filled),
          color: context.theme.colorScheme.onPrimary,
          size: containsThis ? 18 : 50,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clear any loaded thumbnail bytes
    thumbnailBytes = null;
    super.dispose();
  }
}
