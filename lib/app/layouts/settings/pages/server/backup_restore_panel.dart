import 'dart:convert';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_actions.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_dialogs.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_types.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/custom_groups_backup.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/pinned_chats_backup.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/file_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:intl/intl.dart';
import 'package:path/path.dart' hide context;
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class BackupRestorePanel extends StatefulWidget {
  const BackupRestorePanel({super.key});

  @override
  State<BackupRestorePanel> createState() => _BackupRestorePanelState();
}

class _BackupRestorePanelState extends State<BackupRestorePanel> with ThemeHelpers {
  final settings = <Map<String, dynamic>>[].obs;
  final themes = <Map<String, dynamic>>[].obs;
  final fetching = Rx<bool?>(true);

  @override
  void initState() {
    super.initState();
    getBackups();
  }

  void getBackups() async {
    final ok = await BackupRestoreActions.fetchBackups(settings: settings, themes: themes);
    fetching.value = ok ? false : null;
  }

  void refresh() {
    fetching.value = true;
    settings.clear();
    themes.clear();
    getBackups();
  }

  Future<String> defaultName() => BackupRestoreActions.defaultDeviceName();

  Future<BackupDestination?> showMethodDialog() => BackupRestoreDialogs.showBackupDestinationDialog(context);

  @override
  Widget build(BuildContext context) {
    return Obx(() => SettingsScaffold(
        title: "Backup and Restore",
        initialHeader: null,
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        minimalAppBar: true,
        actions: [
          IconButton(
            icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                color: context.theme.colorScheme.onSurface),
            onPressed: refresh,
          ),
        ],
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              if (fetching.value == null || fetching.value == true)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            fetching.value == null ? "Something went wrong!" : "Getting backups...",
                            style: context.theme.textTheme.labelLarge,
                          ),
                        ),
                        if (fetching.value == true) buildProgressIndicator(context, size: 15),
                      ],
                    ),
                  ),
                ),
              if (fetching.value == false) _buildSectionHeader("Settings Backups"),
              if (fetching.value == false) _buildBackupSection(BackupKind.settings),
              if (fetching.value == false) _buildSectionHeader("Theme Backups"),
              if (fetching.value == false) _buildBackupSection(BackupKind.theme),
            ]),
          ),
        ]));
  }

  // ---------------------------------------------------------------------------------------------
  // Section / row building
  // ---------------------------------------------------------------------------------------------

  // SettingsHeader renders as a blank spacer on Samsung skin (by design elsewhere in the app,
  // where Samsung's hero app bar carries the section title instead). This page wants an explicit
  // label on every skin, so Material/Samsung get the M3E section label primitive instead.
  Widget _buildSectionHeader(String text) {
    if (iOS) {
      return SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: text);
    }
    return M3ESectionHeader(label: text);
  }

  Widget _buildBackupSection(BackupKind kind) {
    final items = kind == BackupKind.settings ? settings : themes;
    return SettingsSection(
      backgroundColor: tileColor,
      children: [
        if (items.isEmpty) _buildEmptyState(kind),
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SettingsDivider(),
          _buildBackupTile(kind, items[i]),
        ],
        const SettingsDivider(),
        _buildActionsRow(kind),
      ],
    );
  }

  Widget _buildEmptyState(BackupKind kind) {
    final isSettings = kind == BackupKind.settings;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(
              isSettings
                  ? (iOS ? CupertinoIcons.doc_text : Icons.description_outlined)
                  : (iOS ? CupertinoIcons.paintbrush : Icons.palette_outlined),
              color: context.theme.colorScheme.outline.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              isSettings ? "No settings backups yet" : "No theme backups yet",
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium!
                  .copyWith(color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTile(BackupKind kind, Map<String, dynamic> item) {
    if (kind == BackupKind.settings) {
      final hasDescription = !isNullOrEmpty(item["description"]);
      final timestamp = (item["timestamp"] is int)
          ? DateFormat("MMMM d, yyyy h:mm:ss a").format(DateTime.fromMillisecondsSinceEpoch(item["timestamp"]))
          : null;
      return SettingsTile(
        key: ValueKey(item["name"]),
        backgroundColor: tileColor,
        title: item["name"],
        subtitle: hasDescription ? "$timestamp\n${item["description"]}" : timestamp,
        isThreeLine: hasDescription,
        leading: const SettingsLeadingIcon(
          iosIcon: CupertinoIcons.doc_text,
          materialIcon: Icons.description_outlined,
          containerColor: Colors.blueAccent,
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(iOS ? CupertinoIcons.arrow_2_circlepath : Icons.sync),
            onPressed: () => _syncSettingsBackup(item),
          ),
          IconButton(
            icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
            onPressed: () => _confirmDeleteSettingsBackup(item),
          ),
        ]),
        onTap: () => _confirmRestoreSettingsBackup(item),
        onLongPress: () => _showJson(title: "Settings Data", item: item),
      );
    }

    final hasData = item.containsKey('data');
    final data = item["data"];
    return SettingsTile(
      key: ValueKey(item["name"]),
      backgroundColor: tileColor,
      title: item["name"],
      subtitle: !hasData
          ? "Incompatible backup!"
          : "${Brightness.values[data["colorScheme"]["brightness"]].name.capitalizeFirst!} theme",
      leading: !hasData ? null : _buildThemeSwatchLeading(data),
      trailing: IconButton(
        icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
        onPressed: () => _confirmDeleteThemeBackup(item),
      ),
      onTap: () => _confirmRestoreThemeBackup(item),
      onLongPress: () => _showJson(title: "Theme Data", item: item),
    );
  }

  Widget _buildThemeSwatchLeading(Map<String, dynamic> data) {
    Widget swatch(int color) => Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              color: Color(color),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          swatch(data["colorScheme"]["primary"]),
          swatch(data["colorScheme"]["secondary"]),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          swatch(data["colorScheme"]["primaryContainer"]),
          swatch(data["colorScheme"]["tertiary"]),
        ]),
      ],
    );
  }

  Widget _buildActionsRow(BackupKind kind) {
    const createLabel = "Create New";
    const restoreLabel = "Restore Local";
    final onCreate = () => _onCreateNew(kind);
    final onRestore = () => _onRestoreLocal(kind);

    if (iOS) {
      return Column(children: [
        SettingsTile(
          backgroundColor: tileColor,
          title: createLabel,
          leading: SettingsLeadingIcon(
            iosIcon: CupertinoIcons.add,
            materialIcon: Icons.add,
            containerColor: context.theme.colorScheme.primary,
          ),
          onTap: onCreate,
        ),
        const SettingsDivider(),
        SettingsTile(
          backgroundColor: tileColor,
          title: restoreLabel,
          leading: SettingsLeadingIcon(
            iosIcon: CupertinoIcons.arrow_up_doc,
            materialIcon: Icons.upload_outlined,
            containerColor: context.theme.colorScheme.primary,
          ),
          onTap: onRestore,
        ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: M3EButtonGroup(items: [
        M3EButtonGroupItem(icon: Icons.add, label: createLabel, onPressed: onCreate),
        M3EButtonGroupItem(icon: Icons.upload_outlined, label: restoreLabel, onPressed: onRestore),
      ]),
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Settings backups — actions
  // ---------------------------------------------------------------------------------------------

  void _syncSettingsBackup(Map<String, dynamic> item) {
    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Overwrite Backup?",
      content: const Text(
        "Are you sure you want to replace this backup with your current Settings?",
      ),
      onYes: () async {
        Map<String, dynamic> json = SettingsSvc.settings.toMap(includeAll: false);
        json["description"] = item["description"];
        json["timestamp"] = DateTime.now().millisecondsSinceEpoch;
        json["pinnedChats"] = PinnedChatsBackup.exportList();
        json["customGroups"] = await CustomGroupsBackup.exportList();
        Response response = await HttpSvc.backup.setSettings(item["name"], json);
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        if (response.statusCode != 200) {
          showSnackbar("Error", "Somthing went wrong");
        } else {
          showSnackbar("Success", "Settings exported successfully to server");
        }
        refresh();
      },
    );
  }

  void _confirmDeleteSettingsBackup(Map<String, dynamic> item) {
    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Delete Backup?",
      content: const Text("Are you sure you want to delete this settings backup?"),
      onYes: () {
        BackupRestoreActions.deleteSettings(settings: settings, name: item["name"]);
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  void _confirmRestoreSettingsBackup(Map<String, dynamic> item) {
    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Restore Backup?",
      content: const Text(
        "Are you sure you want to restore this backup, overwriting your current Settings?",
      ),
      onYes: () async {
        Navigator.of(context, rootNavigator: true).pop();
        try {
          Settings.updateFromMap(item);
          showSnackbar("Success", "Settings restored successfully");
          final pinnedChats = item["pinnedChats"] as List<dynamic>?;
          if (pinnedChats != null) {
            final result = await PinnedChatsBackup.restore(pinnedChats);
            if (result.skipped.isNotEmpty && context.mounted) {
              BackupRestoreDialogs.showRestoreSummary(
                context: context,
                title: "Some Pinned Chats Couldn't Be Restored",
                skipped: result.skipped,
              );
            }
          }
          final customGroups = item["customGroups"] as List<dynamic>?;
          if (customGroups != null) {
            final result = await CustomGroupsBackup.restore(customGroups);
            if (result.skipped.isNotEmpty && context.mounted) {
              BackupRestoreDialogs.showRestoreSummary(
                context: context,
                title: "Some Custom Group Chats Couldn't Be Restored",
                skipped: result.skipped,
              );
            }
          }
        } catch (e, s) {
          Logger.error("Failed to restore settings backup!", error: e, trace: s);
          showSnackbar("Error", "Failed to restore settings backup! Error: ${e.toString()}");
        }
      },
    );
  }

  Future<void> _createSettingsBackup() async {
    final destination = await showMethodDialog();
    if (destination == null || !context.mounted) return;
    final deviceName = await defaultName();
    final TextEditingController nameController = TextEditingController(text: deviceName);
    final TextEditingController descController = TextEditingController();

    void onDone(BuildContext _context) async {
      String name = nameController.text;
      final desc = descController.text;
      if (name.isEmpty) {
        return showSnackbar("Error", "Provide a name!");
      } else if (settings.firstWhereOrNull((s) => s["name"] == name) != null) {
        bool yes = false;
        await BackupRestoreDialogs.showConfirmation(
          context: _context,
          title: "Overwrite Backup?",
          content: const Text(
            "Are you sure you want to replace this backup with your current Settings?",
          ),
          onYes: () {
            // Confirmation dialog is on the root navigator (showBBDialog uses
            // useRootNavigator: true), so it must be popped from there.
            Navigator.of(_context, rootNavigator: true).pop();
            yes = true;
          },
        );
        if (!yes) return;
      }
      // Dismiss the name-entry dialog (also on the root navigator) before
      // performing the backup. Using the non-root navigator here would pop
      // the settings page instead, leaving the dialog stuck open.
      Navigator.of(_context, rootNavigator: true).pop();
      Map<String, dynamic> json = SettingsSvc.settings.toMap(includeAll: false);
      if (desc.isNotEmpty) {
        json["description"] = desc;
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      json["timestamp"] = timestamp;
      json["pinnedChats"] = PinnedChatsBackup.exportList();
      json["customGroups"] = await CustomGroupsBackup.exportList();
      if (destination.isCloud) {
        var response = await HttpSvc.backup.setSettings(name, json);
        if (response.statusCode != 200) {
          showSnackbar("Error", "Somthing went wrong");
        } else {
          showSnackbar("Success", "Settings exported successfully to server");
        }
      } else {
        if (kIsWeb) {
          final bytes = utf8.encode(jsonEncode(json));
          final content = base64.encode(bytes);
          html.AnchorElement(href: "data:application/octet-stream;charset=utf-16le;base64,$content")
            ..setAttribute("download", "BB-Settings-$name.json")
            ..click();
          return;
        }
        final downloadsDir = await FilesystemSvc.downloadsDirectory;
        String filePath = join(downloadsDir, "BB-Settings-$name.json");
        final String jsonString = jsonEncode(json);
        if (kIsDesktop) {
          // Let the portal write the file: passing bytes lands it at the
          // real chosen location (sandbox-safe) so reveal opens the right
          // folder, instead of a separate write to a non-granted path.
          String? _filePath = await FilePicker.saveFile(
            initialDirectory: downloadsDir,
            dialogTitle: 'Choose a location to save this file',
            fileName: "BB-Settings-$name.json",
            type: FileType.custom,
            allowedExtensions: ["json"],
            bytes: utf8.encode(jsonString),
          );
          if (_filePath == null) {
            return showSnackbar('Failed', 'You didn\'t select a file path!');
          }
          filePath = _filePath;
        } else {
          File file = File(filePath);
          await file.create(recursive: true);
          await file.writeAsString(jsonString);
        }
        showSnackbar(
          "Success",
          "Settings exported successfully to ${kIsDesktop ? filePath : "downloads folder"}",
          durationMs: kIsDesktop ? 4000 : 2000,
          button: TextButton(
            style: TextButton.styleFrom(backgroundColor: Get.theme.colorScheme.secondary),
            onPressed: () {
              if (kIsDesktop) {
                revealInFileManager(filePath);
              }
              Share.files([filePath]);
            },
            child: Text(kIsDesktop ? "OPEN FOLDER" : "SHARE",
                style: TextStyle(color: context.theme.colorScheme.onSecondary)),
          ),
        );
      }
      refresh();
    }

    if (!context.mounted) return;
    showBBDialog(
      context: context,
      title: "Settings Backup Creation",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  !HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.tab) {
                node.nextFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              cursorColor: context.theme.colorScheme.primary,
              autocorrect: true,
              autofocus: true,
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(20)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(20)),
                labelText: "Name",
              ),
            ),
          ),
          const SizedBox(height: 10),
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.tab) {
                node.previousFocus();
                node.previousFocus(); // This is intentional. Should probably figure out why it's needed
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              cursorColor: context.theme.colorScheme.primary,
              autocorrect: true,
              autofocus: false,
              controller: descController,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => onDone.call(context),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(20)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(20)),
                labelText: "Description (Optional)",
              ),
            ),
          ),
        ],
      ),
      actions: [
        BBDialogAction(
          text: "Cancel",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        BBDialogAction(
          text: "OK",
          isDefault: true,
          onPressed: () => onDone.call(context),
        ),
      ],
    );
  }

  Future<void> _restoreSettingsFromFile() async {
    final res = await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null || !context.mounted) return;
    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Restore Settings?",
      content: const Text(
        "Are you sure you want to restore this backup, overwriting your current Settings?",
      ),
      onYes: () async {
        Navigator.of(context, rootNavigator: true).pop();
        try {
          String jsonString = const Utf8Decoder().convert(res.files.first.bytes!);
          Map<String, dynamic> json = jsonDecode(jsonString);
          Settings.updateFromMap(json);
          showSnackbar("Success", "Settings restored successfully");
          final pinnedChats = json["pinnedChats"] as List<dynamic>?;
          if (pinnedChats != null) {
            final result = await PinnedChatsBackup.restore(pinnedChats);
            if (result.skipped.isNotEmpty && context.mounted) {
              BackupRestoreDialogs.showRestoreSummary(
                context: context,
                title: "Some Pinned Chats Couldn't Be Restored",
                skipped: result.skipped,
              );
            }
          }
          final customGroups = json["customGroups"] as List<dynamic>?;
          if (customGroups != null) {
            final result = await CustomGroupsBackup.restore(customGroups);
            if (result.skipped.isNotEmpty && context.mounted) {
              BackupRestoreDialogs.showRestoreSummary(
                context: context,
                title: "Some Custom Group Chats Couldn't Be Restored",
                skipped: result.skipped,
              );
            }
          }
        } catch (e, s) {
          Logger.error("Failed to restore settings backup!", error: e, trace: s);
          showSnackbar("Error", "Failed to restore settings backup! Error: ${e.toString()}");
        }
      },
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Theme backups — actions
  // ---------------------------------------------------------------------------------------------

  void _confirmDeleteThemeBackup(Map<String, dynamic> item) {
    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Delete Backup?",
      content: const Text("Are you sure you want to delete this theme backup?"),
      onYes: () {
        BackupRestoreActions.deleteTheme(themes: themes, name: item["name"]);
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  void _confirmRestoreThemeBackup(Map<String, dynamic> item) {
    if (!item.containsKey('data')) {
      showSnackbar("Error", "This theme was created on the old theming engine and cannot be restored");
      return;
    }
    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Restore Backup?",
      content: const Text(
        "Are you sure you want to restore this backup, overwriting your current theme?",
      ),
      onYes: () {
        Navigator.of(context, rootNavigator: true).pop();
        try {
          ThemeStruct object = ThemeStruct.fromMap(item);
          object.id = null;
          object.save();
          showSnackbar("Success", "Theme restored successfully");
        } catch (e, s) {
          Logger.error("Failed to restore theme backup!", error: e, trace: s);
          showSnackbar("Error", "Failed to restore theme backup! Error: ${e.toString()}");
        }
      },
    );
  }

  Future<void> _createThemeBackup() async {
    final destination = await showMethodDialog();
    if (destination == null || !context.mounted) return;
    List<ThemeStruct> allThemes = ThemeStruct.getThemes().where((element) => !element.isPreset).toList();
    if (allThemes.isEmpty) {
      return showSnackbar("Notice", "No custom themes found!");
    }
    if (destination.isCloud) {
      bool errored = false;
      for (ThemeStruct e in allThemes) {
        var response = await HttpSvc.backup.setTheme(e.name.characters.take(50).string, e.toMap());
        if (response.statusCode != 200) {
          errored = true;
        }
      }
      if (errored) {
        showSnackbar("Error", "Somthing went wrong");
      } else {
        showSnackbar("Success", "Themes exported successfully to server");
      }
    } else {
      final List<Map<String, dynamic>> themeData = [];
      for (ThemeStruct e in allThemes) {
        themeData.add(e.toMap());
      }
      String jsonStr = jsonEncode(themeData);
      DateTime now = DateTime.now().toLocal();
      final themeFilename =
          "BlueBubbles-theming-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json";
      if (kIsWeb) {
        final bytes = utf8.encode(jsonStr);
        final content = base64.encode(bytes);
        html.AnchorElement(href: "data:application/octet-stream;charset=utf-16le;base64,$content")
          ..setAttribute("download", themeFilename)
          ..click();
        refresh();
        return;
      }
      final downloadsDir = await FilesystemSvc.downloadsDirectory;
      String filePath = join(downloadsDir, themeFilename);
      if (kIsDesktop) {
        // Let the portal write the file: passing bytes lands it at the
        // real chosen location (sandbox-safe) so reveal opens the right
        // folder, instead of a separate write to a non-granted path.
        String? _filePath = await FilePicker.saveFile(
          initialDirectory: downloadsDir,
          dialogTitle: 'Choose a location to save this file',
          fileName: themeFilename,
          type: FileType.custom,
          allowedExtensions: ["json"],
          bytes: utf8.encode(jsonStr),
        );
        if (_filePath == null) {
          return showSnackbar('Failed', 'You didn\'t select a file path!');
        }
        filePath = _filePath;
      } else {
        File file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsString(jsonStr);
      }
      showSnackbar(
        "Success",
        "Theming exported successfully to ${kIsDesktop ? filePath : "downloads folder"}",
        durationMs: kIsDesktop ? 4000 : 2000,
        button: TextButton(
          style: TextButton.styleFrom(backgroundColor: Get.theme.colorScheme.secondary),
          onPressed: () {
            if (kIsDesktop) {
              revealInFileManager(filePath);
              return;
            }
            Share.files([filePath]);
          },
          child: Text(kIsDesktop ? "OPEN FOLDER" : "SHARE",
              style: TextStyle(color: context.theme.colorScheme.onSecondary)),
        ),
      );
    }
    refresh();
  }

  Future<void> _restoreThemesFromFile() async {
    final res = await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null || !context.mounted) return;

    BackupRestoreDialogs.showConfirmation(
      context: context,
      title: "Restore Backup?",
      content: const Text(
        "Are you sure you want to restore this backup, overwriting your current theme?",
      ),
      onYes: () {
        Navigator.of(context, rootNavigator: true).pop();
        try {
          String jsonString = const Utf8Decoder().convert(res.files.first.bytes!);
          List<dynamic> json = jsonDecode(jsonString);
          for (var e in json) {
            ThemeStruct object = ThemeStruct.fromMap(e);
            if (object.isPreset) continue;
            object.id = null;
            object.save();
          }
          showSnackbar("Success", "Theming restored successfully");
        } catch (e, s) {
          Logger.error("Failed to restore theme backup!", error: e, trace: s);
          showSnackbar("Error", "Failed to restore theme backup! Error: ${e.toString()}");
        }
      },
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------------------------------

  void _showJson({required String title, required Map<String, dynamic> item}) {
    const encoder = JsonEncoder.withIndent("     ");
    final str = encoder.convert(item);
    BackupRestoreDialogs.showJsonData(
      context: context,
      title: title,
      jsonText: str,
    );
  }

  Future<void> _onCreateNew(BackupKind kind) =>
      kind == BackupKind.settings ? _createSettingsBackup() : _createThemeBackup();

  Future<void> _onRestoreLocal(BackupKind kind) =>
      kind == BackupKind.settings ? _restoreSettingsFromFile() : _restoreThemesFromFile();
}
