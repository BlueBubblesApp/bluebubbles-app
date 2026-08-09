import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:flutter/material.dart';

/// Resolves a `dynamicWallpaperId` + config map to the actual animated
/// wallpaper widget via [DynamicWallpaperRegistry]. Used both as the live
/// chat background (`GradientBackground`) and as the small-scale preview on
/// the picker gallery tiles / config screen — callers control interactivity
/// and clipping, this just renders.
class DynamicWallpaperView extends StatelessWidget {
  final String? wallpaperId;
  final Map<String, dynamic>? config;

  const DynamicWallpaperView({super.key, required this.wallpaperId, required this.config});

  @override
  Widget build(BuildContext context) {
    final definition = DynamicWallpaperRegistry.byId(wallpaperId);
    if (definition == null) return const SizedBox.shrink();
    final resolvedConfig = config ?? definition.defaultConfig(context, isIMessage: true);
    return IgnorePointer(child: definition.buildView(context, resolvedConfig));
  }
}
