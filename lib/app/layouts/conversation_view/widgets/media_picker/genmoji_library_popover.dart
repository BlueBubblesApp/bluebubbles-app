import 'dart:async';
import 'dart:math' as math;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/genmoji_library_tile.dart';
import 'package:bluebubbles/models/genmoji.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const double _popoverWidth = 380;
const double _popoverHeight = 460;
const double _margin = 12;

/// Opens the desktop Genmoji library as a popover above [anchorContext] (the composer's `+`
/// button): a searchable grid of the Mac's Genmoji with a "New" button to create one.
///
/// Clicking a Genmoji attaches it and closes the popover; right-clicking offers Delete. Click
/// outside or press Escape to dismiss. Only open this when `ServerDetails.supportsGenmoji`.
Future<void> showGenmojiLibraryPopover(BuildContext anchorContext, ConversationViewController controller) async {
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final overlayBox = navigator.overlay!.context.findRenderObject() as RenderBox;
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  final anchor = anchorBox == null || !anchorBox.attached
      ? Rect.fromLTWH(_margin, overlayBox.size.height - _margin, 0, 0)
      : anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox) & anchorBox.size;

  unawaited(GenmojiLibrarySvc.sync());
  controller.showingOverlays = true;
  try {
    await showGeneralDialog(
      context: anchorContext,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, _) {
        final size = MediaQuery.sizeOf(context);
        final width = math.min(_popoverWidth, size.width - _margin * 2);
        // Above the button, as tall as fits between it and the top of the window.
        final height = math.min(_popoverHeight, anchor.top - _margin * 2).clamp(200.0, _popoverHeight);
        final left = anchor.left.clamp(_margin, math.max(_margin, size.width - width - _margin)).toDouble();
        final bottom = math.max(_margin, size.height - anchor.top + 8);
        return Stack(
          children: [
            Positioned(
              left: left,
              bottom: bottom,
              width: width,
              height: height,
              child: _GenmojiLibraryPopover(controller: controller),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    );
  } finally {
    controller.showingOverlays = false;
  }
}

class _GenmojiLibraryPopover extends StatefulWidget {
  const _GenmojiLibraryPopover({required this.controller});

  final ConversationViewController controller;

  @override
  State<_GenmojiLibraryPopover> createState() => _GenmojiLibraryPopoverState();
}

class _GenmojiLibraryPopoverState extends State<_GenmojiLibraryPopover> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  ConversationViewController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _create() async {
    final attached = await AttachmentActions.createGenmoji(context, controller);
    if (attached && mounted) _close();
  }

  Future<void> _onTap(GenmojiLibraryEntry entry) async {
    if (AttachmentActions.isGenmojiAttached(controller, entry)) {
      return AttachmentActions.toggleLibraryGenmoji(controller, entry);
    }
    await AttachmentActions.attachLibraryGenmoji(controller, entry);
    if (mounted && AttachmentActions.isGenmojiAttached(controller, entry)) _close();
  }

  Future<void> _onContextMenu(GenmojiLibraryEntry entry, TapUpDetails details) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = overlay.globalToLocal(details.globalPosition);
    final attached = AttachmentActions.isGenmojiAttached(controller, entry);
    final scheme = context.theme.colorScheme;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position & Size.zero, Offset.zero & overlay.size),
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem(value: 'attach', child: Text(attached ? "Remove from Message" : "Attach")),
        PopupMenuItem(
          value: 'delete',
          child: Text("Delete…", style: TextStyle(color: scheme.error)),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'attach':
        await _onTap(entry);
      case 'delete':
        await AttachmentActions.deleteGenmoji(context, controller, entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final textTheme = context.theme.textTheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
              child: Row(
                children: [
                  Text("Genmoji", style: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Obx(
                    () => GenmojiLibrarySvc.syncing.value
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: CupertinoActivityIndicator(radius: 8),
                          )
                        : IconButton(
                            tooltip: "Refresh",
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.refresh_rounded, size: 20, color: scheme.outline),
                            onPressed: () => GenmojiLibrarySvc.sync(force: true),
                          ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: _create,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text("New"),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                style: textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: "Search Genmoji",
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: scheme.outline),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: Obx(() => _buildBody(context))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                "Right-click a Genmoji to delete it",
                style: textTheme.bodySmall!.copyWith(color: scheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final svc = GenmojiLibrarySvc;
    final all = svc.entries.toList();

    if (all.isEmpty) {
      if (!svc.loaded.value || svc.syncing.value) return const Center(child: CupertinoActivityIndicator());
      final error = svc.syncError.value;
      if (error != null) {
        return _Message(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't Load Genmoji",
          message: error,
          action: ("Retry", () => svc.sync(force: true)),
        );
      }
      final unreadable = svc.unavailableReason.value != null;
      return _Message(
        icon: unreadable ? Icons.lock_outline_rounded : Icons.auto_awesome_rounded,
        highlight: !unreadable,
        title: unreadable ? "Library Unavailable" : "No Genmoji Yet",
        message: unreadable
            ? "Your Mac's Genmoji library couldn't be read, but you can still create new ones."
            : "Describe any emoji you can imagine and your Mac will create it. Your Genmoji will show up here.",
        action: ("Create Genmoji", _create),
      );
    }

    final query = _search.text.trim().toLowerCase();
    final entries = query.isEmpty ? all : all.where((e) => e.description.toLowerCase().contains(query)).toList();
    if (entries.isEmpty) {
      return _Message(icon: Icons.search_off_rounded, message: "No Genmoji match \"${_search.text.trim()}\".");
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 72,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: entries.length + (query.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (query.isEmpty) {
          if (index == 0) {
            return Tooltip(
              message: "New Genmoji",
              child: GenmojiCreateTile(onTap: _create, compact: true),
            );
          }
          index -= 1;
        }
        final entry = entries[index];
        return Tooltip(
          message: entry.description,
          waitDuration: const Duration(milliseconds: 400),
          child: GenmojiLibraryTile(
            key: ValueKey("genmoji-${entry.identifier}"),
            entry: entry,
            controller: controller,
            padding: const EdgeInsets.all(6),
            onTap: () => _onTap(entry),
            onSecondaryTapUp: (details) => _onContextMenu(entry, details),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message, this.title, this.action, this.highlight = false});

  final IconData icon;
  final String? title;
  final String message;
  final (String, VoidCallback)? action;

  /// Draws the icon in the theme's accent, for an inviting state rather than a problem.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final textTheme = context.theme.textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: highlight ? scheme.primary : scheme.outline),
            const SizedBox(height: 12),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium!.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium!.copyWith(color: scheme.outline),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: action!.$2,
                icon: Icon(action!.$1 == "Retry" ? Icons.refresh_rounded : Icons.auto_awesome_rounded, size: 18),
                label: Text(action!.$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
