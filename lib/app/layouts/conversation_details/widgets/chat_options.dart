import 'package:bluebubbles/app/layouts/conversation_details/dialogs/chat_sync_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_page.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/sync_time_range_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/theme_studio_panel.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/background/background_crop.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_io/io.dart';

typedef _RowBuilder = Widget Function(BuildContext context);

class _OptionRow {
  final bool enabled;
  final _RowBuilder build;

  const _OptionRow({required this.enabled, required this.build});
}

class ChatOptions extends StatefulWidget {
  const ChatOptions({super.key, required this.chat});

  final Chat chat;

  @override
  State<StatefulWidget> createState() => _ChatOptionsState();
}

/// iOS replacement for the old single 679-line flat [SettingsSection] — grouped into the same
/// four labeled sections as the Material/Samsung [ExpressiveChatOptions]: Appearance,
/// Conversation, Content & data, Danger zone. Every handler/condition below is unchanged from
/// the flat version; this is a presentation-only reorganization.
class _ChatOptionsState extends State<ChatOptions> with ThemeHelpers {
  Chat get chat => widget.chat;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppearanceGroup(context),
          Obx(() => _buildConversationGroup(context)),
          _buildContentGroup(context),
          Obx(() => _buildDangerZoneGroup(context)),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String label, List<_OptionRow> rows) {
    final enabledRows = rows.where((r) => r.enabled).toList(growable: false);
    if (enabledRows.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < enabledRows.length; i++) {
      children.add(enabledRows[i].build(context));
      if (i < enabledRows.length - 1) children.add(const SettingsDivider());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: label),
        SettingsSection(backgroundColor: tileColor, children: children),
      ],
    );
  }

  Widget _buildAppearanceGroup(BuildContext context) {
    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Change Chat Avatar",
          subtitle: "Set a custom avatar for this chat, or reset it back to the default",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.person : Icons.person_outlined),
          ),
          onTap: () async {
            if (chat.customAvatarPath != null) {
              showBBDialog(
                context: context,
                title: "Custom Avatar",
                body: "You already have a custom avatar for this chat. What would you like to do?",
                actions: [
                  BBDialogAction(text: "Cancel", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
                  BBDialogAction(
                    text: "Reset",
                    onPressed: () async {
                      await ChatsSvc.setChatCustomAvatarPath(chat, null);
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                  ),
                  BBDialogAction(
                    text: "Set New",
                    isDefault: true,
                    onPressed: () async {
                      Navigator.of(context, rootNavigator: true).pop();
                      final result = await Get.to<String?>(() => AvatarCrop(chat: chat));
                      if (result != null) {
                        await ChatsSvc.setChatCustomAvatarPath(chat, result);
                      }
                    },
                  ),
                ],
              );
            } else {
              final result = await Get.to<String?>(() => AvatarCrop(chat: chat));
              if (result == null) return;
              await ChatsSvc.setChatCustomAvatarPath(chat, result);
            }
          },
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Custom Background",
          subtitle: "Set a custom background for this chat, or reset it back to the default",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.photo : Icons.wallpaper),
          ),
          onTap: () {
            final backgroundPath = FilesystemSvc.getExistingChatBackgroundPath(chat.guid);
            if (backgroundPath != null) {
              showBBDialog(
                context: context,
                title: "Custom Background",
                body: "You already have a custom background for this chat. What would you like to do?",
                actions: [
                  BBDialogAction(text: "Cancel", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
                  BBDialogAction(
                    text: "Remove",
                    isDestructive: true,
                    color: context.theme.colorScheme.error,
                    onPressed: () async {
                      final File bgFile = File(backgroundPath);
                      if (await bgFile.exists()) bgFile.delete();
                      await ChatsSvc.setChatCustomBackgroundPath(chat, null);
                      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                    },
                  ),
                  BBDialogAction(
                    text: "Set New",
                    isDefault: true,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      Get.to(() => BackgroundCrop(chat: chat));
                    },
                  ),
                ],
              );
            } else {
              Get.to(() => BackgroundCrop(chat: chat));
            }
          },
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Set Custom Theme",
          subtitle: "Choose light and dark chat themes in Theme Studio",
          backgroundColor: tileColor,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.paintbrush : Icons.palette_outlined),
          ),
          onTap: () {
            final lightThemeName = chat.customThemeLight ?? ThemeStruct.getLightTheme().name;
            final darkThemeName = chat.customThemeDark ?? ThemeStruct.getDarkTheme().name;

            Get.to(
              () => ThemeStudioPanel(
                config: ThemeStudioPanelConfig(
                  initialLightThemeName: lightThemeName,
                  initialDarkThemeName: darkThemeName,
                  adaptiveImagePath: FilesystemSvc.getExistingChatBackgroundPath(chat.guid),
                  adaptiveThemeScopeKey: chat.guid,
                  onApply: (lightTheme, darkTheme) async {
                    final globalLight = ThemeStruct.getLightTheme().name;
                    final globalDark = ThemeStruct.getDarkTheme().name;
                    await ChatsSvc.setChatCustomThemes(
                      chat,
                      lightTheme: lightTheme.name == globalLight ? null : lightTheme.name,
                      darkTheme: darkTheme.name == globalDark ? null : darkTheme.name,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ];

    return _group(context, "Appearance", rows);
  }

  Widget _buildConversationGroup(BuildContext context) {
    final chatState = ChatsSvc.getChatState(chat.guid);

    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb && !kIsDesktop && (FilesystemSvc.androidInfo?.version.sdkInt ?? 0) >= 30,
        build: (context) => SettingsTile(
          title: "Notification Settings",
          subtitle: "Customize notification sounds, importance, and more for this specific chat",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.bell : Icons.notifications_on),
          ),
          isThreeLine: true,
          onTap: () async {
            await MethodChannelSvc.actions.openConversationNotificationSettings(
              channelId: chat.guid,
              displayName: chat.getTitle(),
            );
          },
        ),
      ),
      _OptionRow(
        enabled: chat.isGroup,
        build: (context) => SettingsSwitch(
          title: "Lock Chat Name",
          subtitle: "Keep the current chat name on this device, even if someone else in the chat changes it",
          initialVal: chatState?.lockChatName.value ?? chat.lockChatName,
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatLockName(chatState.chat, value);
            } else {
              chat.lockChatName = value;
              chat.saveAsync(updateLockChatName: true);
            }
          },
        ),
      ),
      _OptionRow(
        enabled: chat.isGroup,
        build: (context) => SettingsSwitch(
          title: "Lock Chat Icon",
          subtitle: "Keep the current chat icon on this device, even if someone else in the chat changes it",
          initialVal: chatState?.lockChatIcon.value ?? chat.lockChatIcon,
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatLockIcon(chatState.chat, value);
            } else {
              chat.lockChatIcon = value;
              chat.saveAsync(updateLockChatIcon: true);
            }
          },
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsSwitch(
          title: "Pin Conversation",
          subtitle: "Keep this chat pinned to the top of your conversation list",
          initialVal: chatState?.isPinned.value ?? chat.isPinned!,
          onChanged: (value) {
            ChatsSvc.setChatPinned(chatState?.chat ?? chat, !(chatState?.isPinned.value ?? chat.isPinned!));
          },
          backgroundColor: tileColor,
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsSwitch(
          title: "Mute Conversation",
          subtitle: "Silence notifications for this chat",
          initialVal: (chatState?.muteType.value ?? chat.muteType) == "mute",
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatMuted(chatState.chat, value);
            } else {
              chat.toggleMuteAsync(value);
            }
          },
          backgroundColor: tileColor,
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsSwitch(
          title: "Archive Conversation",
          subtitle: "Hide this chat from your main conversation list",
          initialVal: chatState?.isArchived.value ?? chat.isArchived!,
          onChanged: (value) {
            ChatsSvc.setChatArchived(chatState?.chat ?? chat, value);
          },
          backgroundColor: tileColor,
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value,
        build: (context) => SettingsSwitch(
          title: "Send Typing Indicators",
          subtitle: "Send typing indicators for this chat, overriding the global setting",
          initialVal:
              chatState?.autoSendTypingIndicators.value ?? SettingsSvc.settings.privateSendTypingIndicators.value,
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatAutoSendTypingIndicators(chatState.chat, value);
            } else {
              chat.toggleAutoTypeAsync(value);
            }
          },
          backgroundColor: tileColor,
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value,
        build: (context) => SettingsSwitch(
          title: "Follow Global Setting",
          subtitle:
              "Typing Indicators ${SettingsSvc.settings.privateSendTypingIndicators.value ? "Enabled" : "Disabled"}",
          initialVal: chatState?.autoSendTypingIndicators.value == null,
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatAutoSendTypingIndicators(
                chatState.chat,
                value ? null : SettingsSvc.settings.privateSendTypingIndicators.value,
              );
            } else {
              chat.toggleAutoTypeAsync(value ? null : SettingsSvc.settings.privateSendTypingIndicators.value);
            }
          },
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value,
        build: (context) => SettingsSwitch(
          title: "${SettingsSvc.settings.privateManualMarkAsRead.value ? "Automatically " : ""}Send Read Receipts",
          subtitle: "Send read receipts for this chat, overriding the global setting",
          initialVal: chatState?.autoSendReadReceipts.value ?? SettingsSvc.settings.privateMarkChatAsRead.value,
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatAutoSendReadReceipts(chatState.chat, value);
            } else {
              chat.toggleAutoReadAsync(value);
            }
          },
          backgroundColor: tileColor,
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value,
        build: (context) => SettingsSwitch(
          title: "Follow Global Setting",
          subtitle:
              "${SettingsSvc.settings.privateManualMarkAsRead.value ? "Automatic " : ""}Read Receipts ${SettingsSvc.settings.privateMarkChatAsRead.value ? "Enabled" : "Disabled"}",
          initialVal: chatState?.autoSendReadReceipts.value == null,
          onChanged: (value) {
            if (chatState != null) {
              ChatsSvc.setChatAutoSendReadReceipts(
                chatState.chat,
                value ? null : SettingsSvc.settings.privateMarkChatAsRead.value,
              );
            } else {
              chat.toggleAutoReadAsync(value ? null : SettingsSvc.settings.privateMarkChatAsRead.value);
            }
          },
        ),
      ),
    ];

    return _group(context, "Conversation", rows);
  }

  Widget _buildContentGroup(BuildContext context) {
    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Chat Stats",
          subtitle: "See your texting patterns, response times, and activity for this chat",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.chart_bar_alt_fill : Icons.insights),
          ),
          isThreeLine: true,
          onTap: () => NavigationSvc.push(context, ChatStatsPage(chat: chat)),
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Storage",
          subtitle: "See attachment storage usage for this chat and free up space",
          backgroundColor: tileColor,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.chart_pie : Icons.pie_chart_outline),
          ),
          isThreeLine: true,
          onTap: () => NavigationSvc.push(context, StorageAnalyzerPanel(initialChat: chat)),
        ),
      ),
      _OptionRow(
        enabled: true,
        build: (context) => SettingsTile(
          title: "View Bookmarks",
          subtitle: "See your bookmarked messages",
          backgroundColor: tileColor,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.bookmark : Icons.bookmark),
          ),
          onTap: () async {
            showBookmarksThread(cvc(widget.chat), context);
          },
        ),
      ),
      _OptionRow(
        enabled: true,
        build: (context) => SettingsTile(
          title: "Fetch Chat Details",
          subtitle: "Get the latest chat title and participants from the server",
          backgroundColor: tileColor,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.chat_bubble : Icons.sms),
          ),
          onTap: () async {
            final updatedChat = await ChatsSvc.fetchChat(chat.guid);
            if (updatedChat != null) {
              if (chat.isGroup) {
                await Chat.getIcon(updatedChat, force: true);
              }

              ChatsSvc.updateChat(updatedChat, override: true);
            }
            showSnackbar("Notice", "Fetched details!");
          },
        ),
      ),
      _OptionRow(
        enabled: true,
        build: (context) => SettingsTile(
          title: "Sync Messages",
          subtitle: "Fetch and sync messages from the server for a selected time range",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.replay),
          ),
          onTap: () async {
            final range = await showSyncTimeRangeDialog(context);
            if (range == null || !context.mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  ChatSyncDialog(chat: chat, initialMessage: "Syncing messages...", start: range.start, end: range.end),
            );
          },
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Download Chat Transcript",
          subtitle: kIsDesktop
              ? "Left click for a plaintext transcript\nRight click for a PDF transcript"
              : "Tap for a plaintext transcript\nTap and hold for a PDF transcript",
          isThreeLine: true,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.doc_text : Icons.note_outlined),
          ),
          onTap: () async {
            final date = await showTimeframePicker("Select Timeframe", context, additionalTimeframes: {"6 Hours": 6});
            if (date == null) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Generating document...", style: context.theme.textTheme.titleLarge),
                content: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[const SizedBox(height: 15.0), buildProgressIndicator(context)],
                ),
                backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
              ),
              barrierDismissible: false,
            );
            final messages = (await Chat.getMessagesAsync(
              chat,
              limit: 0,
              includeDeleted: true,
            )).reversed.where((e) => e.dateCreated!.isAfter(date));
            if (messages.isEmpty) {
              Navigator.of(context, rootNavigator: true).pop();
              showSnackbar("Error", "No messages found!");
              return;
            }
            final List<String> lines = [];
            for (Message m in messages) {
              final readStr = m.dateRead != null ? "Read: ${buildFullDate(m.dateRead!)}, " : "";
              final deliveredStr = m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
              final sentStr = "Sent: ${buildFullDate(m.dateCreated!)}";
              final text = m.getNotificationText(withSender: true);
              final line = "($readStr$deliveredStr$sentStr) $text";
              lines.add(line);
            }
            final now = DateTime.now().toLocal();
            final filePath = p.join(
              await FilesystemSvc.downloadsDirectory,
              "${chat.getTitle().replaceAll(RegExp(r'[<>:"/\\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt",
            );
            File file = File(filePath);
            await file.create(recursive: true);
            await file.writeAsString(lines.join('\n'));
            Navigator.of(context, rootNavigator: true).pop();
            showSnackbar("Success", "Saved transcript to the downloads folder");
          },
          onLongPress: () async {
            final date = await showTimeframePicker("Select Timeframe", context, additionalTimeframes: {"6 Hours": 6});
            if (date == null) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Generating PDF...", style: context.theme.textTheme.titleLarge),
                content: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[const SizedBox(height: 15.0), buildProgressIndicator(context)],
                ),
                backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
              ),
              barrierDismissible: false,
            );
            final messages = (await Chat.getMessagesAsync(
              chat,
              limit: 0,
              includeDeleted: true,
            )).reversed.where((e) => e.dateCreated!.isAfter(date));
            if (messages.isEmpty) {
              Navigator.of(context, rootNavigator: true).pop();
              showSnackbar("Error", "No messages found!");
              return;
            }
            final doc = pw.Document();
            final List<String> timestamps = [];
            final List<dynamic> content = [];
            final List<Size?> dimensions = [];
            for (Message m in messages) {
              final readStr = m.dateRead != null ? "Read: ${buildFullDate(m.dateRead!)}, " : "";
              final deliveredStr = m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
              final sentStr = "Sent: ${buildFullDate(m.dateCreated!)}";
              if (m.hasAttachments) {
                final attachments = m.dbAttachments.where(
                  (e) => e.guid != null && ["image/png", "image/jpg", "image/jpeg"].contains(e.mimeType),
                );
                final files = attachments
                    .map((e) => AttachmentsSvc.getContent(e, autoDownload: false))
                    .whereType<PlatformFile>();
                if (files.isNotEmpty) {
                  for (PlatformFile f in files) {
                    final a = attachments.firstWhere((e) => e.transferName == f.name);
                    timestamps.add(readStr + deliveredStr + sentStr);
                    content.add(pw.MemoryImage(await File(f.path!).readAsBytes()));
                    final aspectRatio = (a.width ?? 150.0) / (a.height ?? 150.0);
                    dimensions.add(Size(400, aspectRatio * 400));
                  }
                }
                timestamps.add(readStr + deliveredStr + sentStr);
                content.add(m.getNotificationText(withSender: true));
                dimensions.add(null);
              } else {
                timestamps.add(readStr + deliveredStr + sentStr);
                content.add(m.getNotificationText(withSender: true));
                dimensions.add(null);
              }
            }
            final font = await PdfGoogleFonts.openSansRegular();
            doc.addPage(
              pw.MultiPage(
                maxPages: 1000,
                header: (pw.Context context) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    chat.getTitle(),
                    textScaleFactor: 2,
                    style: pw.Theme.of(context).defaultTextStyle.copyWith(fontWeight: pw.FontWeight.bold, font: font),
                  ),
                ),
                build: (pw.Context context) => [
                  pw.Partitions(
                    children: [
                      pw.Partition(
                        child: pw.Table(
                          children: List.generate(
                            timestamps.length,
                            (index) => pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                  child: pw.Text(
                                    timestamps[index],
                                    style: pw.Theme.of(context).defaultTextStyle.copyWith(font: font),
                                  ),
                                ),
                                pw.Container(
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                    child: content[index] is pw.MemoryImage
                                        ? pw.Image(
                                            content[index],
                                            width: dimensions[index]!.width,
                                            height: dimensions[index]!.height,
                                          )
                                        : pw.Text(content[index].toString(), style: pw.TextStyle(font: font)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            final now = DateTime.now().toLocal();
            final filePath = p.join(
              await FilesystemSvc.downloadsDirectory,
              "${chat.getTitle().replaceAll(RegExp(r'[<>:"/\\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.pdf",
            );
            File file = File(filePath);
            await file.create(recursive: true);
            await file.writeAsBytes(await doc.save());
            Navigator.of(context, rootNavigator: true).pop();
            showSnackbar("Success", "Saved transcript to the downloads folder");
          },
        ),
      ),
    ];

    return _group(context, "Content & data", rows);
  }

  Widget _buildDangerZoneGroup(BuildContext context) {
    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => SettingsTile(
          title: "Clear Transcript",
          subtitle: "Delete all messages for this chat on this device",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
          ),
          onTap: () {
            showBBDialog(
              context: context,
              title: "Are You Sure?",
              body:
                  'Clearing the transcript will permanently delete all messages in this chat. It will also prevent any previous messages from being loaded by the app, until you perform a full reset.',
              actions: [
                BBDialogAction(text: "Cancel", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
                BBDialogAction(
                  text: "Yes",
                  isDefault: true,
                  onPressed: () async {
                    Navigator.of(context, rootNavigator: true).pop();
                    chat.clearTranscript();
                    EventDispatcherSvc.emit("refresh-messagebloc", {"chatGuid": chat.guid});
                  },
                ),
              ],
            );
          },
        ),
      ),
      _OptionRow(
        enabled: OutgoingMsgHandler.pendingChatGuids.contains(chat.guid),
        build: (context) => SettingsTile(
          title: "Cancel Outgoing Messages",
          subtitle: "Cancel all messages currently queued to be sent in this chat",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(
              iOS ? CupertinoIcons.xmark_circle : Icons.cancel_outlined,
              color: context.theme.colorScheme.error,
            ),
          ),
          onTap: () => _showCancelConfirmation(context),
        ),
      ),
      _OptionRow(
        enabled:
            chat.handles.length > 2 &&
            SettingsSvc.settings.enablePrivateAPI.value &&
            SettingsSvc.serverDetails.supportsGroupChatManagement,
        build: (context) => SettingsTile(
          title: "Leave Chat",
          subtitle: "You will no longer receive messages from this group",
          trailing: Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Icon(iOS ? CupertinoIcons.arrow_right_square : Icons.logout, color: context.theme.colorScheme.error),
          ),
          onTap: () => _leaveChat(context),
        ),
      ),
    ];

    return _group(context, "Danger zone", rows);
  }

  Future<void> _leaveChat(BuildContext context) async {
    await showAreYouSure(
      context,
      title: "Leave Chat?",
      content: const Text(
        "Are you sure you want to leave this chat? You will no longer receive messages from this group.",
      ),
      yesText: "Leave",
      yesColor: context.theme.colorScheme.error,
      onNo: () => Navigator.of(context, rootNavigator: true).pop(),
      onYes: () async {
        Navigator.of(context, rootNavigator: true).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const BBProgressDialog(title: "Leaving chat..."),
        );
        final response = await HttpSvc.chat.leave(chat.guid);
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        if (response.statusCode == 200) {
          showSnackbar("Notice", "Left chat successfully!");
        } else {
          showSnackbar("Error", "Failed to leave chat!");
        }
      },
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    showBBDialog(
      context: context,
      title: "Cancel Outgoing Messages?",
      body: 'This will cancel all messages currently waiting to be sent in this chat. They will be marked as failed.',
      actions: [
        BBDialogAction(text: "Keep Sending", onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
        BBDialogAction(
          text: "Cancel Messages",
          isDestructive: true,
          color: context.theme.colorScheme.error,
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await OutgoingMsgHandler.cancelPendingForChat(chat.guid);
          },
        ),
      ],
    );
  }
}
