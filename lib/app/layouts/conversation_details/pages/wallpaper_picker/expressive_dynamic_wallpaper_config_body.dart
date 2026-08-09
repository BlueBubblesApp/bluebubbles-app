import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/config_field_row.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Material/Samsung M3E config body — same generic field rendering as the
/// Cupertino body, wrapped in `M3ESection` tonal cards instead of
/// `SettingsSection`.
class ExpressiveDynamicWallpaperConfigBody extends StatelessWidget {
  final List<ConfigField> fields;

  const ExpressiveDynamicWallpaperConfigBody({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        for (final field in fields)
          M3ESection(
            backgroundColor: context.tileColor,
            children: [buildConfigFieldRow(context, field, expressive: true)],
          ),
      ],
    );
  }
}
