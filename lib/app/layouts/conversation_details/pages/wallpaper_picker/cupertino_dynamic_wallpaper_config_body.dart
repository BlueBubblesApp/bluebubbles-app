import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/config_field_row.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

class CupertinoDynamicWallpaperConfigBody extends StatelessWidget {
  final List<ConfigField> fields;

  const CupertinoDynamicWallpaperConfigBody({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          SettingsSection(
            backgroundColor: context.tileColor,
            children: [buildConfigFieldRow(context, fields[i], expressive: false)],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
