import 'dart:convert';

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

  void deleteSettings(String name) {
    BackupRestoreActions.deleteSettings(settings: settings, name: name);
  }

  void deleteTheme(String name) {
    BackupRestoreActions.deleteTheme(themes: themes, name: name);
  }

  Future<String> defaultName() async {
    return BackupRestoreActions.defaultDeviceName();
  }

  Future<BackupDestination?> showMethodDialog() async {
    return BackupRestoreDialogs.showBackupDestinationDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => SettingsScaffold(
            title: "Backup and Restore",
            initialHeader: fetching.value == false ? "Settings Backups" : null,
            iosSubtitle: iosSubtitle,
            materialSubtitle: materialSubtitle,
            tileColor: tileColor,
            headerColor: headerColor,
            actions: [
              IconButton(
                icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                    color: context.theme.colorScheme.onSurface),
                onPressed: () {
                  fetching.value = true;
                  settings.clear();
                  themes.clear();
                  getBackups();
                },
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
                  if (fetching == false)
                    SettingsSection(
                      backgroundColor: tileColor,
                      children: [
                        if (settings.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              findChildIndexCallback: (key) =>
                                  findChildIndexByKey(settings, key, (item) => item["name"]),
                              itemBuilder: (context, index) {
                                final item = settings[index];
                                return ListTile(
                                  key: ValueKey(item["name"]),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                  mouseCursor: MouseCursor.defer,
                                  title: RichText(
                                    text: TextSpan(
                                      style: context.textTheme.titleMedium,
                                      children: [
                                        TextSpan(text: item["name"]),
                                        const TextSpan(text: "\n"),
                                        TextSpan(
                                          text: (item["timestamp"] is int)
                                              ? DateFormat("MMMM d, yyyy h:mm:ss a")
                                                  .format(DateTime.fromMillisecondsSinceEpoch(item["timestamp"]))
                                              : null,
                                          style: context.textTheme.titleSmall!
                                              .copyWith(color: context.theme.colorScheme.outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                  subtitle: !isNullOrEmpty(item["description"]) ? Text(item["description"]) : null,
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(
                                        icon: Icon(iOS ? CupertinoIcons.arrow_2_circlepath : Icons.sync),
                                        onPressed: () {
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
                                              Navigator.of(context, rootNavigator: true).pop();
                                              if (response.statusCode != 200) {
                                                showSnackbar(
                                                  "Error",
                                                  "Somthing went wrong",
                                                );
                                              } else {
                                                showSnackbar(
                                                  "Success",
                                                  "Settings exported successfully to server",
                                                );
                                              }
                                              fetching.value = true;
                                              settings.clear();
                                              themes.clear();
                                              getBackups();
                                            },
                                          );
                                        }),
                                    IconButton(
                                        icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                                        onPressed: () {
                                          BackupRestoreDialogs.showConfirmation(
                                            context: context,
                                            title: "Delete Backup?",
                                            content:
                                                const Text("Are you sure you want to delete this settings backup?"),
                                            onYes: () {
                                              deleteSettings(item["name"]);
                                              Navigator.of(context, rootNavigator: true).pop();
                                            },
                                          );
                                        })
                                  ]),
                                  onTap: () {
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
                                          showSnackbar(
                                              "Error", "Failed to restore settings backup! Error: ${e.toString()}");
                                        }
                                      },
                                    );
                                  },
                                  onLongPress: () async {
                                    const encoder = JsonEncoder.withIndent("     ");
                                    final str = encoder.convert(item);
                                    BackupRestoreDialogs.showJsonData(
                                      context: context,
                                      title: "Settings Data",
                                      jsonText: str,
                                    );
                                  },
                                  isThreeLine: !isNullOrEmpty(item["description"]),
                                );
                              },
                              itemCount: settings.length,
                            ),
                          ),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            mouseCursor: MouseCursor.defer,
                            title: Text("Create New",
                                style: context.theme.textTheme.bodyLarge!
                                    .copyWith(color: context.theme.colorScheme.primary)),
                            leading: Container(
                              width: 40 * SettingsSvc.settings.avatarScale.value,
                              height: 40 * SettingsSvc.settings.avatarScale.value,
                              decoration: BoxDecoration(
                                  color:
                                      !iOS ? null : context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                  border: iOS ? null : Border.all(color: context.theme.colorScheme.primary, width: 3)),
                              child: Icon(
                                Icons.add,
                                color: context.theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            onTap: () async {
                              final destination = await showMethodDialog();
                              if (destination == null) return;
                              final deviceName = await defaultName();
                              final TextEditingController nameController = TextEditingController(text: deviceName);
                              final TextEditingController descController = TextEditingController();

                              void onDone(_context) async {
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
                                    showSnackbar(
                                      "Error",
                                      "Somthing went wrong",
                                    );
                                  } else {
                                    showSnackbar(
                                      "Success",
                                      "Settings exported successfully to server",
                                    );
                                  }
                                } else {
                                  if (kIsWeb) {
                                    final bytes = utf8.encode(jsonEncode(json));
                                    final content = base64.encode(bytes);
                                    html.AnchorElement(
                                        href: "data:application/octet-stream;charset=utf-16le;base64,$content")
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
                                      style: TextButton.styleFrom(
                                        backgroundColor: Get.theme.colorScheme.secondary,
                                      ),
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
                                fetching.value = true;
                                settings.clear();
                                themes.clear();
                                getBackups();
                              }

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
                                        onSubmitted: (_) {
                                          onDone.call(context);
                                        },
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
                            },
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            mouseCursor: MouseCursor.defer,
                            title: Text("Restore Local",
                                style: context.theme.textTheme.bodyLarge!
                                    .copyWith(color: context.theme.colorScheme.primary)),
                            leading: Container(
                              width: 40 * SettingsSvc.settings.avatarScale.value,
                              height: 40 * SettingsSvc.settings.avatarScale.value,
                              decoration: BoxDecoration(
                                  color:
                                      !iOS ? null : context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                  border: iOS ? null : Border.all(color: context.theme.colorScheme.primary, width: 3)),
                              child: Icon(
                                Icons.upload,
                                color: context.theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            onTap: () async {
                              final res = await FilePicker.pickFiles(
                                  withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                              if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
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
                            },
                          ),
                        ),
                      ],
                    ),
                  if (fetching == false)
                    SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Theme Backups",
                    ),
                  if (fetching == false)
                    SettingsSection(
                      backgroundColor: tileColor,
                      children: [
                        if (themes.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              findChildIndexCallback: (key) => findChildIndexByKey(themes, key, (item) => item['name']),
                              itemBuilder: (context, index) {
                                final item = themes[index];
                                final data = item["data"];
                                return ListTile(
                                  key: ValueKey(item["name"]),
                                  mouseCursor: MouseCursor.defer,
                                  title: Text(item["name"]),
                                  subtitle: !item.containsKey('data')
                                      ? Text("Incompatible backup!",
                                          style: context.theme.textTheme.bodyMedium!
                                              .copyWith(color: context.theme.colorScheme.error))
                                      : Text(
                                          "${Brightness.values[data["colorScheme"]["brightness"]].name.capitalizeFirst!} theme"),
                                  leading: !item.containsKey('data')
                                      ? null
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Padding(
                                                  padding: const EdgeInsets.all(3),
                                                  child: Container(
                                                    height: 12,
                                                    width: 12,
                                                    decoration: BoxDecoration(
                                                      color: Color(data["colorScheme"]["primary"]),
                                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(3),
                                                  child: Container(
                                                    height: 12,
                                                    width: 12,
                                                    decoration: BoxDecoration(
                                                      color: Color(data["colorScheme"]["secondary"]),
                                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Padding(
                                                  padding: const EdgeInsets.all(3),
                                                  child: Container(
                                                    height: 12,
                                                    width: 12,
                                                    decoration: BoxDecoration(
                                                      color: Color(data["colorScheme"]["primaryContainer"]),
                                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(3),
                                                  child: Container(
                                                    height: 12,
                                                    width: 12,
                                                    decoration: BoxDecoration(
                                                      color: Color(data["colorScheme"]["tertiary"]),
                                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                  trailing: IconButton(
                                    icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                                    onPressed: () {
                                      BackupRestoreDialogs.showConfirmation(
                                        context: context,
                                        title: "Delete Backup?",
                                        content: const Text("Are you sure you want to delete this theme backup?"),
                                        onYes: () {
                                          deleteTheme(item["name"]);
                                          Navigator.of(context, rootNavigator: true).pop();
                                        },
                                      );
                                    },
                                  ),
                                  onTap: () async {
                                    if (!item.containsKey('data')) {
                                      return showSnackbar("Error",
                                          "This theme was created on the old theming engine and cannot be restored");
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
                                          showSnackbar(
                                              "Error", "Failed to restore theme backup! Error: ${e.toString()}");
                                        }
                                      },
                                    );
                                  },
                                  onLongPress: () async {
                                    const encoder = JsonEncoder.withIndent("     ");
                                    final str = encoder.convert(item);
                                    BackupRestoreDialogs.showJsonData(
                                      context: context,
                                      title: "Theme Data",
                                      jsonText: str,
                                    );
                                  },
                                );
                              },
                              itemCount: themes.length,
                            ),
                          ),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            mouseCursor: MouseCursor.defer,
                            title: Text("Create New",
                                style: context.theme.textTheme.bodyLarge!
                                    .copyWith(color: context.theme.colorScheme.primary)),
                            leading: Container(
                              width: 40 * SettingsSvc.settings.avatarScale.value,
                              height: 40 * SettingsSvc.settings.avatarScale.value,
                              decoration: BoxDecoration(
                                  color:
                                      !iOS ? null : context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                  border: iOS ? null : Border.all(color: context.theme.colorScheme.primary, width: 3)),
                              child: Icon(
                                Icons.add,
                                color: context.theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            onTap: () async {
                              final destination = await showMethodDialog();
                              if (destination == null) return;
                              List<ThemeStruct> allThemes =
                                  ThemeStruct.getThemes().where((element) => !element.isPreset).toList();
                              if (allThemes.isEmpty) {
                                return showSnackbar(
                                  "Notice",
                                  "No custom themes found!",
                                );
                              }
                              if (destination.isCloud) {
                                bool errored = false;
                                for (ThemeStruct e in allThemes) {
                                  var response =
                                      await HttpSvc.backup.setTheme(e.name.characters.take(50).string, e.toMap());
                                  if (response.statusCode != 200) {
                                    errored = true;
                                  }
                                }
                                if (errored) {
                                  showSnackbar(
                                    "Error",
                                    "Somthing went wrong",
                                  );
                                } else {
                                  showSnackbar(
                                    "Success",
                                    "Themes exported successfully to server",
                                  );
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
                                  html.AnchorElement(
                                      href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                                    ..setAttribute("download", themeFilename)
                                    ..click();
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
                                    style: TextButton.styleFrom(
                                      backgroundColor: Get.theme.colorScheme.secondary,
                                    ),
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
                              fetching.value = true;
                              settings.clear();
                              themes.clear();
                              getBackups();
                            },
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            mouseCursor: MouseCursor.defer,
                            title: Text("Restore Local",
                                style: context.theme.textTheme.bodyLarge!
                                    .copyWith(color: context.theme.colorScheme.primary)),
                            leading: Container(
                              width: 40 * SettingsSvc.settings.avatarScale.value,
                              height: 40 * SettingsSvc.settings.avatarScale.value,
                              decoration: BoxDecoration(
                                  color:
                                      !iOS ? null : context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                  border: iOS ? null : Border.all(color: context.theme.colorScheme.primary, width: 3)),
                              child: Icon(
                                Icons.upload,
                                color: context.theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            onTap: () async {
                              final res = await FilePicker.pickFiles(
                                  withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                              if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

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
                            },
                          ),
                        ),
                      ],
                    ),
                ]),
              ),
            ]));
  }
}
