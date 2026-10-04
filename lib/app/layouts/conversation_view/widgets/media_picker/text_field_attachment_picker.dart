import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_picker_file.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hand_signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:universal_io/io.dart';

/// Optimized attachment picker that avoids loading bytes until absolutely necessary
/// This significantly improves performance and reduces memory usage
class AttachmentPicker extends StatefulWidget {
  const AttachmentPicker({
    super.key,
    required this.controller,
  });

  final ConversationViewController controller;

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker> with ThemeHelpers {
  List<AssetEntity> _images = <AssetEntity>[];
  bool _isLoadingImages = false;
  bool _permissionDenied = false;

  ConversationViewController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    getAttachments();
  }

  Future<void> getAttachments() async {
    if (kIsDesktop || kIsWeb || _isLoadingImages) return;

    setState(() {
      _isLoadingImages = true;
    });

    try {
      // Wait for opening animation to complete
      await Future.delayed(const Duration(milliseconds: 250));

      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
      if (mounted && _permissionDenied) setState(() => _permissionDenied = false);

      List<AssetPathEntity> list = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: false, // false = descending, newest first
            ),
          ],
        ),
      );
      if (list.isNotEmpty) {
        _images = await list.first.getAssetListRange(start: 0, end: 24);

        // See if there is a recent attachment
        if (_images.isNotEmpty && DateTime.now().toLocal().isWithin(_images.first.modifiedDateTime, minutes: 2)) {
          final file = await _images.first.file;
          if (file != null) {
            // Don't load bytes here - let the attachment service handle it when needed
            EventDispatcherSvc.emit(
                'add-custom-smartreply',
                PlatformFile(
                  path: file.path,
                  name: file.path.split('/').last,
                  size: await file.length(),
                  bytes: null, // Don't preload bytes
                ));
          }
        }
      }
    } catch (e, s) {
      Logger.error("Failed to load attachments", error: e, trace: s);
      showSnackbar("Error", "Failed to load attachments: $e", type: SnackbarType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    }
  }

  Future<void> openFullCamera({String type = 'camera'}) async {
    bool granted = (await Permission.camera.request()).isGranted;
    if (!granted) {
      showSnackbar("Error", "Camera access was denied!", type: SnackbarType.error);
      return;
    }

    if (type == 'video') {
      final micGranted = (await Permission.microphone.request()).isGranted;
      if (!micGranted) {
        showSnackbar("Error", "Microphone access was denied!", type: SnackbarType.error);
        return;
      }
    }

    final XFile? file;
    if (type == 'video') {
      file = await ImagePicker().pickVideo(source: ImageSource.camera);
    } else {
      file = await ImagePicker().pickImage(source: ImageSource.camera);
    }

    if (file != null) {
      // Don't preload bytes - only store the path
      controller.pickedAttachments.add(PlatformFile(
        path: file.path,
        name: file.path.split('/').last,
        size: await file.length(),
        bytes: null, // Will be loaded when actually sending
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.theme.colorScheme.surface,
      child: SizedBox(
        height: 340,
        child: RefreshIndicator(
          onRefresh: () async {
            await getAttachments();
          },
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (OverscrollIndicatorNotification overscroll) {
              // Prevent stretchy effect
              overscroll.disallowIndicator();
              return true;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 340,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: CustomScrollView(
                    physics: ThemeSwitcher.getScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    slivers: <Widget>[
                      // Quick action list
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 5),
                        sliver: _buildActionList(),
                      ),
                      // Image grid
                      const SliverPadding(padding: EdgeInsets.only(left: 5, right: 5)),
                      // Image grid
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 5),
                        sliver: _buildImageGrid(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionList() {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: 175,
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.9, 0.95, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            children: [
              _QuickActionItem(
                icon: Icons.camera_alt_rounded,
                label: 'Photo',
                color: const Color(0xFF34C759),
                onTap: () => openFullCamera(type: 'camera'),
              ),
              _QuickActionItem(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: const Color(0xFFFF3B30),
                onTap: () => openFullCamera(type: 'video'),
              ),
              _QuickActionItem(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: const Color(0xFF5856D6),
                onTap: _handleGallery,
              ),
              _QuickActionItem(
                icon: Icons.folder_rounded,
                label: 'Files',
                color: const Color(0xFF007AFF),
                onTap: _handleFilePicker,
              ),
              _QuickActionItem(
                icon: Icons.location_on_rounded,
                label: 'Location',
                color: const Color(0xFF32ADE6),
                onTap: _handleLocation,
              ),
              _QuickActionItem(
                icon: Icons.schedule_rounded,
                label: 'Schedule',
                color: const Color(0xFFFF9500),
                onTap: () => _handleSchedule(context),
              ),
              _QuickActionItem(
                icon: Icons.draw_rounded,
                label: 'Handwritten',
                color: const Color(0xFFAF52DE),
                onTap: () => _handleHandwritten(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGallery() async {
    if (kIsDesktop || kIsWeb) return;
    final List<XFile> files = await ImagePicker().pickMultiImage();
    for (final file in files) {
      final size = await file.length();
      if (size / 1024000 > 1000) {
        showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.", type: SnackbarType.error);
        continue;
      }
      controller.pickedAttachments.add(PlatformFile(
        path: file.path,
        name: file.path.split('/').last,
        size: size,
        bytes: null,
      ));
    }
  }

  Future<void> _handleFilePicker() async {
    final res = await FilePicker.pickFiles(
      withReadStream: true,
      allowMultiple: true,
    );
    if (res == null || res.files.isEmpty) return;

    for (pf.PlatformFile file in res.files) {
      if (file.size / 1024000 > 1000) {
        showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.", type: SnackbarType.error);
        continue;
      }
      controller.pickedAttachments.add(PlatformFile(
        path: file.path,
        name: file.name,
        bytes: null,
        size: file.size,
      ));
    }
  }

  Future<void> _handleLocation() async {
    await Share.location(controller.chat);
  }

  Future<void> _handleSchedule(BuildContext context) async {
    if (controller.pickedAttachments.isNotEmpty) {
      return showSnackbar("Error", "Remove all attachments before scheduling!", type: SnackbarType.error);
    } else if (controller.replyToMessage != null || controller.subjectTextController.text.isNotEmpty) {
      return showSnackbar("Error", "Private API features are not supported when scheduling!", type: SnackbarType.error);
    }

    final date = await showTimeframePicker("Pick date and time", context, presetsAhead: true);
    if (date != null && date.isAfter(DateTime.now())) {
      controller.scheduledDate.value = date;
    }
  }

  Future<void> _handleHandwritten(BuildContext context) async {
    Color selectedColor = context.theme.colorScheme.bubble(context, controller.chat.isIMessage);

    final result = await ColorPicker(
      color: selectedColor,
      onColorChanged: (Color newColor) {
        selectedColor = newColor;
      },
      title: Text(
        "Select Color",
        style: context.theme.textTheme.titleLarge,
      ),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: <ColorPickerType, bool>{
        ColorPickerType.wheel: true,
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        parseShortHexCode: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        dialogActionButtons: true,
      ),
    ).showPickerDialog(
      context,
      barrierDismissible: false,
      constraints: BoxConstraints(
        minHeight: 480,
        minWidth: NavigationSvc.width(context) - 70,
        maxWidth: NavigationSvc.width(context) - 70,
      ),
    );

    if (result && context.mounted) {
      final control = HandSignatureControl();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Draw Handwriten Message",
              style: context.theme.textTheme.titleLarge,
            ),
            content: AspectRatio(
              aspectRatio: 1,
              child: Container(
                constraints: const BoxConstraints.expand(),
                child: HandSignature(
                  control: control,
                  color: selectedColor,
                  width: 1.0,
                  maxWidth: 10.0,
                  type: SignatureDrawType.shape,
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  "Cancel",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(
                  "OK",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final bytes = await control.toImage(height: 512, fit: false);
                  if (bytes != null) {
                    final uint8 = bytes.buffer.asUint8List();
                    controller.pickedAttachments.add(PlatformFile(
                      path: null,
                      name: "handwriten-${controller.pickedAttachments.length + 1}.png",
                      bytes: uint8,
                      size: uint8.lengthInBytes,
                      balloonBundleId: 'com.apple.Handwriting.HandwritingProvider',
                    ));
                  }
                },
              ),
            ],
            backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
          );
        },
      );
    }
  }

  Widget _buildStatusSliver({
    required IconData icon,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: 280,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: context.theme.colorScheme.outline),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.bodySmall!.copyWith(
                    color: context.theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: context.theme.colorScheme.primary,
                    foregroundColor: context.theme.colorScheme.onPrimary,
                  ),
                  onPressed: onPressed,
                  child: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_isLoadingImages) {
      return const SliverToBoxAdapter(
        // Explicit width so the item occupies space in the horizontal CustomScrollView.
        child: SizedBox(
          width: 280,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    if (_permissionDenied) {
      return _buildStatusSliver(
        icon: Icons.photo_library_outlined,
        message: "Photo access is required to browse your gallery.",
        buttonLabel: "Grant Access",
        onPressed: () async {
          final ps = await PhotoManager.requestPermissionExtend();
          if (ps.hasAccess) {
            await getAttachments();
          } else {
            await openAppSettings();
          }
        },
      );
    }

    // Access was granted but no photos came back. This reliably covers:
    // - Limited access with no photos selected (photo_manager collapses
    //   PermissionState back to 'authorized' after presentLimited(), so
    //   ps.isLimited is not trustworthy post-flow)
    // - Fully authorized but genuinely empty library
    if (_images.isEmpty) {
      // PhotoManager.presentLimited() is broken on Android — it silently does
      // nothing on most devices (known upstream issue #1357). On Android, direct
      // the user to App Settings where they can update their photo selection.
      // On iOS, presentLimited() works correctly.
      final isAndroid = !kIsWeb && Platform.isAndroid;
      return _buildStatusSliver(
        icon: Icons.photo_library_outlined,
        message: isAndroid
            ? "No photos are accessible. Tap below to open Settings and update your photo access."
            : "No photos are accessible. Tap below to choose which photos this app can access.",
        buttonLabel: isAndroid ? "Open Settings" : "Select Photos",
        onPressed: () async {
          if (isAndroid) {
            await openAppSettings();
          } else {
            await PhotoManager.presentLimited();
          }
          await getAttachments();
        },
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final element = _images[index];
          return AttachmentPickerFile(
            key: Key("AttachmentPickerFile-${element.id}"),
            data: element,
            controller: controller,
            onTap: () async {
              final file = await element.file;
              if (file == null) return;

              if ((await file.length()) / 1024000 > 1000) {
                showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.",
                    type: SnackbarType.error);
                return;
              }

              if (controller.pickedAttachments.firstWhereOrNull((e) => e.path == file.path) != null) {
                controller.pickedAttachments.removeWhere((e) => e.path == file.path);
              } else {
                // Don't preload bytes - only store the path
                controller.pickedAttachments.add(PlatformFile(
                  path: file.path,
                  name: file.path.split('/').last,
                  size: await file.length(),
                  bytes: null, // Will be loaded when actually sending
                ));
              }
            },
          );
        },
        childCount: _images.length,
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = color.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: context.theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
