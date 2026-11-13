import 'dart:async';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_picker_file.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/genmoji_library_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/open_pigeon_view.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  /// The grid shows the Mac's Genmoji library instead of the photo library (see
  /// `ConversationViewController.showGenmojiLibrary`, which the back button also clears).
  bool get _showGenmoji => controller.showGenmojiLibrary.value;
  late final Worker _genmojiWorker;

  ConversationViewController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Every opening starts on photos.
    controller.showGenmojiLibrary.value = false;
    _genmojiWorker = ever<bool>(controller.showGenmojiLibrary, (_) {
      if (mounted) setState(() {});
    });
    getAttachments();
  }

  @override
  void dispose() {
    _genmojiWorker.dispose();
    super.dispose();
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
                'offer-recent-photo',
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
            if (_showGenmoji) {
              await GenmojiLibrarySvc.sync(force: true);
            } else {
              await getAttachments();
            }
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
                onTap: () => AttachmentActions.pickFiles(controller),
              ),
              _QuickActionItem(
                icon: Icons.location_on_rounded,
                label: 'Location',
                color: const Color(0xFF32ADE6),
                onTap: () => AttachmentActions.shareLocation(controller),
              ),
              _QuickActionItem(
                icon: Icons.schedule_rounded,
                label: 'Schedule',
                color: const Color(0xFFFF9500),
                onTap: () => AttachmentActions.schedule(context, controller),
              ),
              _QuickActionItem(
                icon: Icons.draw_rounded,
                label: 'Handwritten',
                color: const Color(0xFFAF52DE),
                onTap: () => AttachmentActions.handwritten(context, controller),
              ),
              if (OpenPigeon.offered && controller.chat.isIMessage)
                _QuickActionItem(
                  icon: Icons.sports_esports_rounded,
                  label: 'Games',
                  color: const Color(0xFFD4A72C),
                  onTap: () => showOpenPigeonPicker(context, controller),
                ),
              // v2 (Swift) server only. Switches the grid to the Mac's Genmoji library (and back);
              // whether the Mac can draw new ones is asked when the creator opens.
              if (SettingsSvc.getServerDetails().supportsGenmoji)
                _QuickActionItem(
                  icon: Icons.add_reaction_rounded,
                  label: 'Genmoji',
                  color: const Color(0xFFFF2D55),
                  selected: _showGenmoji,
                  onTap: _toggleGenmoji,
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

  void _toggleGenmoji() {
    controller.showGenmojiLibrary.value = !_showGenmoji;
    if (_showGenmoji) unawaited(GenmojiLibrarySvc.sync());
  }

  Widget _buildStatusSliver({
    required IconData icon,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? title,
    double width = 280,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: width,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: context.theme.colorScheme.outline),
                const SizedBox(height: 8),
                if (title != null) ...[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.theme.textTheme.titleSmall!.copyWith(color: context.theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                ],
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
    if (_showGenmoji) return _buildGenmojiGrid();

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

  static const int _genmojiRows = 3;
  static const double _genmojiSpacing = 8;

  /// "Photos" (back to the photo grid) and "New", in that order: the first column of the
  /// Genmoji grid, sized like its tiles.
  List<Widget> get _genmojiLeadingTiles => [
        _BackToPhotosTile(onTap: () => controller.showGenmojiLibrary.value = false),
        GenmojiCreateTile(onTap: () => AttachmentActions.createGenmoji(context, controller)),
      ];

  /// The Mac's Genmoji library in the photo grid's place, newest first. The first column
  /// starts with "Photos" and "New", so both are always a tap away. Tap attaches (or
  /// un-attaches), long press offers to delete.
  Widget _buildGenmojiGrid() => Obx(() => _buildGenmojiContent());

  Widget _buildGenmojiContent() {
    final svc = GenmojiLibrarySvc;
    final entries = svc.entries.toList();
    final leading = _genmojiLeadingTiles;

    if (entries.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          // The same column the grid starts with, at the size the grid would give it.
          SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, constraints) {
              final extent = (constraints.maxHeight - _genmojiSpacing * (_genmojiRows - 1)) / _genmojiRows;
              return SizedBox(
                width: extent,
                child: Column(
                  children: [
                    for (final (i, tile) in leading.indexed) ...[
                      if (i > 0) const SizedBox(height: _genmojiSpacing),
                      SizedBox.square(dimension: extent, child: tile),
                    ],
                  ],
                ),
              );
            }),
          ),
          _buildGenmojiStatus(svc),
        ],
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _genmojiRows,
        crossAxisSpacing: _genmojiSpacing,
        mainAxisSpacing: _genmojiSpacing,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < leading.length) return leading[index];
          final entry = entries[index - leading.length];
          return GenmojiLibraryTile(
            key: ValueKey("genmoji-${entry.identifier}"),
            entry: entry,
            controller: controller,
            onTap: () => AttachmentActions.toggleLibraryGenmoji(controller, entry),
            onLongPress: () => AttachmentActions.deleteGenmoji(context, controller, entry),
          );
        },
        childCount: leading.length + entries.length,
      ),
    );
  }

  /// Loading, error and empty states, beside the Photos / New column (so narrower than the
  /// photo grid's messages).
  Widget _buildGenmojiStatus(GenmojiLibraryService svc) {
    if (!svc.loaded.value || svc.syncing.value) {
      return const SliverToBoxAdapter(
        child: SizedBox(width: 220, child: Center(child: CupertinoActivityIndicator())),
      );
    }
    final error = svc.syncError.value;
    if (error != null) {
      return _buildStatusSliver(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't Load Genmoji",
        message: error,
        buttonLabel: "Retry",
        onPressed: () => svc.sync(force: true),
        width: 220,
      );
    }
    final unreadable = svc.unavailableReason.value != null;
    return _buildStatusSliver(
      icon: unreadable ? Icons.lock_outline_rounded : Icons.auto_awesome_rounded,
      title: unreadable ? "Library Unavailable" : "No Genmoji Yet",
      message: unreadable
          ? "Your Mac's Genmoji library couldn't be read, but you can still create new ones."
          : "Describe any emoji you can imagine and your Mac will create it. Your Genmoji will show up here.",
      buttonLabel: "Create Genmoji",
      onPressed: () => AttachmentActions.createGenmoji(context, controller),
      width: 220,
    );
  }
}

/// Leaves the Genmoji library for the photo grid the picker opens with.
class _BackToPhotosTile extends StatelessWidget {
  const _BackToPhotosTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Semantics(
      button: true,
      label: "Back to photos",
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16, color: scheme.onSurface),
                  const SizedBox(width: 2),
                  Icon(Icons.photo_library_rounded, size: 22, color: scheme.onSurface),
                ],
              ),
              const SizedBox(height: 4),
              Text("Photos", style: context.theme.textTheme.labelMedium),
            ],
          ),
        ),
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
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Drawn as the active mode (the Genmoji grid is showing).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bgColor = color.withValues(alpha: selected ? 0.24 : 0.12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: color, width: 1.5) : null,
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
              // The active mode reads as dismissible: tapping it again goes back to photos.
              if (selected) Icon(Icons.close_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
