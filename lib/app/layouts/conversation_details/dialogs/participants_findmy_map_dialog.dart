import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

/// Opens a 90%-height bottom sheet with an interactive map for conversation participants.
Future<void> showParticipantsFindMyMap(
  BuildContext context, {
  required FindMyController controller,
  VoidCallback? onSheetClosed,
}) async {
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        alignment: Alignment.bottomCenter,
        child: _themedSheet(
          context,
          _ParticipantsFindMyMapSheet(controller: controller),
        ),
      ),
    );
  } finally {
    onSheetClosed?.call();
  }
}

Widget _themedSheet(BuildContext parentContext, Widget child) {
  final theme = Theme.of(parentContext);
  final adaptive = AdaptiveTheme.maybeOf(parentContext);
  if (adaptive == null) return Theme(data: theme, child: child);
  return AdaptiveTheme(
    light: adaptive.theme,
    dark: adaptive.darkTheme,
    initial: adaptive.mode,
    builder: (_, __) => Theme(data: theme, child: child),
  );
}

class _ParticipantsFindMyMapSheet extends StatefulWidget {
  final FindMyController controller;

  const _ParticipantsFindMyMapSheet({required this.controller});

  @override
  State<_ParticipantsFindMyMapSheet> createState() => _ParticipantsFindMyMapSheetState();
}

class _ParticipantsFindMyMapSheetState extends State<_ParticipantsFindMyMapSheet> with ThemeHelpers {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String get _title {
    final count = widget.controller.participantFriendsWithLocation.length;
    return count == 1 ? "Location" : "Locations";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ColoredBox(
            color: context.theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: NavigationToolbar(
                  middle: Text(_title, style: context.theme.textTheme.titleLarge),
                  centerMiddle: true,
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "Done",
                        style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FindMyMapWidget(
              controller: widget.controller,
              mapController: _mapController,
              interactive: true,
              initialZoom: 13,
              onMapReady: () => widget.controller.fitMapToParticipantMarkers(_mapController),
            ),
          ),
        ],
      ),
    );
  }
}
