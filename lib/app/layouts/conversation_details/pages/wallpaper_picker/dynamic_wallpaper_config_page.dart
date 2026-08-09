import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/cupertino_dynamic_wallpaper_config_body.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/expressive_dynamic_wallpaper_config_body.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Config screen for a single dynamic wallpaper. Fully generic — it doesn't
/// know anything about "wave" or "floating shapes" specifically, it just
/// renders whatever [DynamicWallpaperDefinition.buildConfigFields] returns
/// for the current config, live-previewing the result at the top. This is
/// what makes new dynamic wallpaper types free of any UI work here.
class DynamicWallpaperConfigPage extends StatefulWidget {
  final Chat chat;
  final DynamicWallpaperDefinition definition;
  final Map<String, dynamic>? initialConfig;

  const DynamicWallpaperConfigPage({
    super.key,
    required this.chat,
    required this.definition,
    this.initialConfig,
  });

  @override
  State<DynamicWallpaperConfigPage> createState() => _DynamicWallpaperConfigPageState();
}

class _DynamicWallpaperConfigPageState extends State<DynamicWallpaperConfigPage> with ThemeHelpers {
  late Map<String, dynamic> config;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    config = widget.initialConfig ?? widget.definition.defaultConfig(context, isIMessage: widget.chat.isIMessage);
  }

  void _onConfigChanged(Map<String, dynamic> next) => setState(() => config = next);

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    await ChatsSvc.setChatDynamicWallpaper(widget.chat, widget.definition.id, config);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.definition.buildConfigFields(context, config, _onConfigChanged);

    return BBScaffold(
      appBar: BBAppBar(
        titleText: widget.definition.displayName,
        leading: buildBackButton(context),
        actions: [
          TextButton(
            onPressed: _applying ? null : _apply,
            child: Text(
              "Apply",
              style: context.theme.textTheme.bodyLarge!.copyWith(
                color: _applying ? context.theme.colorScheme.outline : context.theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: DynamicWallpaperView(wallpaperId: widget.definition.id, config: config),
              ),
            ),
          ),
          Expanded(
            child: ThemeSwitcher(
              iOSSkin: CupertinoDynamicWallpaperConfigBody(fields: fields),
              materialSkin: ExpressiveDynamicWallpaperConfigBody(fields: fields),
              samsungSkin: ExpressiveDynamicWallpaperConfigBody(fields: fields),
            ),
          ),
        ],
      ),
    );
  }
}
