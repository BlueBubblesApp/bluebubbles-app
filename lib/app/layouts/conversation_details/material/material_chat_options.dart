import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/chat_sync_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_page.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/sync_time_range_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/theme_studio_panel.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/background/background_crop.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
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

/// Data-driven expressive replacement for [ChatOptions] on the Material/Samsung skins —
/// four labeled `M3ESection` groups instead of one 679-line flat `SettingsSection`.
///
/// Every handler below is ported verbatim from `chat_options.dart`; this is a presentation
/// change only, except for two intentional parity fixes documented inline (View Bookmarks,
/// Leave Chat).
class ExpressiveChatOptions extends StatelessWidget {
  final Chat chat;

  const ExpressiveChatOptions({super.key, required this.chat});

  Color _switchColor(BuildContext context) => context.theme.colorScheme.primary.lightenOrDarken(15);

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

  Widget _group(BuildContext context, String label, List<_OptionRow> rows, {M3ESectionTone tone = M3ESectionTone.neutral}) {
    final children = rows.where((r) => r.enabled).map((r) => r.build(context)).toList(growable: false);
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        M3ESectionHeader(label: label),
        M3ESection(
          backgroundColor: context.tileColor,
          tone: tone,
          children: children,
        ),
      ],
    );
  }

  Widget _buildAppearanceGroup(BuildContext context) {
    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          icon: Icons.person_outlined,
          title: "Change chat avatar",
          supportingText: "Set or reset this chat's avatar",
          onTap: () async {
            if (chat.customAvatarPath != null) {
              showBBDialog(
                context: context,
                title: "Custom Avatar",
                body: "You already have a custom avatar for this chat. What would you like to do?",
                actions: [
                  BBDialogAction(
                    text: "Cancel",
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                  BBDialogAction(
                    text: "Reset",
                    onPressed: () async {
                      await ChatsSvc.setChatCustomAvatarPath(chat, null);
                      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
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
        build: (context) => M3EListTile(
          icon: Icons.wallpaper,
          title: "Custom background",
          supportingText: "Set or reset this chat's background",
          onTap: () {
            final backgroundPath = FilesystemSvc.getExistingChatBackgroundPath(chat.guid);
            if (backgroundPath != null) {
              showBBDialog(
                context: context,
                title: "Custom Background",
                body: "You already have a custom background for this chat. What would you like to do?",
                actions: [
                  BBDialogAction(
                    text: "Cancel",
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
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
        build: (context) => M3EListTile(
          icon: Icons.palette_outlined,
          title: "Set custom theme",
          supportingText: "Pick light and dark themes",
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
    final typingOverride = chatState?.autoSendTypingIndicators.value;
    final readReceiptOverride = chatState?.autoSendReadReceipts.value;

    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb && !kIsDesktop && (FilesystemSvc.androidInfo?.version.sdkInt ?? 0) >= 30,
        build: (context) => M3EListTile(
          icon: Icons.notifications_on,
          title: "Notification settings",
          supportingText: "Sounds, importance, and more",
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
        build: (context) => M3EListTile(
          icon: Icons.lock_outline,
          title: "Lock chat name",
          supportingText: "Ignore name changes from others",
          trailing: Switch(
            value: chatState?.lockChatName.value ?? chat.lockChatName,
            activeThumbColor: _switchColor(context),
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
      ),
      _OptionRow(
        enabled: chat.isGroup,
        build: (context) => M3EListTile(
          icon: Icons.lock_outline,
          title: "Lock chat icon",
          supportingText: "Ignore icon changes from others",
          trailing: Switch(
            value: chatState?.lockChatIcon.value ?? chat.lockChatIcon,
            activeThumbColor: _switchColor(context),
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
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          icon: Icons.push_pin_outlined,
          title: "Pin conversation",
          supportingText: "Pin to the top of your chat list",
          trailing: Switch(
            value: chatState?.isPinned.value ?? chat.isPinned!,
            activeThumbColor: _switchColor(context),
            onChanged: (value) {
              ChatsSvc.setChatPinned(chatState?.chat ?? chat, !(chatState?.isPinned.value ?? chat.isPinned!));
            },
          ),
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          icon: (chatState?.muteType.value ?? chat.muteType) == "mute"
              ? Icons.notifications_off_outlined
              : Icons.notifications_active_outlined,
          title: "Mute conversation",
          supportingText: "Silence notifications",
          trailing: Switch(
            value: (chatState?.muteType.value ?? chat.muteType) == "mute",
            activeThumbColor: _switchColor(context),
            onChanged: (value) {
              if (chatState != null) {
                ChatsSvc.setChatMuted(chatState.chat, value);
              } else {
                chat.toggleMuteAsync(value);
              }
            },
          ),
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          icon: Icons.archive_outlined,
          title: "Archive conversation",
          supportingText: "Hide from your main chat list",
          trailing: Switch(
            value: chatState?.isArchived.value ?? chat.isArchived!,
            activeThumbColor: _switchColor(context),
            onChanged: (value) {
              ChatsSvc.setChatArchived(chatState?.chat ?? chat, value);
            },
          ),
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value,
        build: (context) => M3EListTile(
          icon: Icons.keyboard_outlined,
          title: "Send typing indicators",
          supportingText: "Overrides the global setting",
          trailing: Switch(
            value: typingOverride ?? SettingsSvc.settings.privateSendTypingIndicators.value,
            activeThumbColor: _switchColor(context),
            onChanged: (value) {
              if (chatState != null) {
                ChatsSvc.setChatAutoSendTypingIndicators(chatState.chat, value);
              } else {
                chat.toggleAutoTypeAsync(value);
              }
            },
          ),
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value && typingOverride != null,
        build: (context) => M3EListTile(
          nested: true,
          icon: Icons.sync_outlined,
          title: "Follow global setting",
          supportingText: "Typing indicators ${SettingsSvc.settings.privateSendTypingIndicators.value ? "enabled" : "disabled"}",
          trailing: Switch(
            value: typingOverride == null,
            activeThumbColor: _switchColor(context),
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
      ),
      _OptionRow(
        enabled: !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value,
        build: (context) => M3EListTile(
          icon: Icons.mark_email_read_outlined,
          title: "${SettingsSvc.settings.privateManualMarkAsRead.value ? "Automatically send " : "Send "}read receipts",
          supportingText: "Overrides the global setting",
          trailing: Switch(
            value: readReceiptOverride ?? SettingsSvc.settings.privateMarkChatAsRead.value,
            activeThumbColor: _switchColor(context),
            onChanged: (value) {
              if (chatState != null) {
                ChatsSvc.setChatAutoSendReadReceipts(chatState.chat, value);
              } else {
                chat.toggleAutoReadAsync(value);
              }
            },
          ),
        ),
      ),
      _OptionRow(
        enabled:
            !kIsWeb && !chat.isGroup && SettingsSvc.settings.enablePrivateAPI.value && readReceiptOverride != null,
        build: (context) => M3EListTile(
          nested: true,
          icon: Icons.sync_outlined,
          title: "Follow global setting",
          supportingText:
              "${SettingsSvc.settings.privateManualMarkAsRead.value ? "Automatic " : ""}read receipts ${SettingsSvc.settings.privateMarkChatAsRead.value ? "enabled" : "disabled"}",
          trailing: Switch(
            value: readReceiptOverride == null,
            activeThumbColor: _switchColor(context),
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
      ),
    ];

    return _group(context, "Conversation", rows);
  }

  Widget _buildContentGroup(BuildContext context) {
    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          icon: Icons.insights,
          title: "Chat stats",
          supportingText: "Texting patterns and activity",
          onTap: () => NavigationSvc.push(context, ChatStatsPage(chat: chat)),
        ),
      ),
      // Parity fix — "View bookmarks" was gated behind `if (iOS)` even though the flow
      // it calls has nothing iOS-specific about it. Material users have simply never
      // had access.
      _OptionRow(
        enabled: true,
        build: (context) => M3EListTile(
          icon: Icons.bookmark_outline,
          title: "View bookmarks",
          supportingText: "Your bookmarked messages",
          onTap: () => showBookmarksThread(cvc(chat), context),
        ),
      ),
      _OptionRow(
        enabled: true,
        build: (context) => M3EListTile(
          icon: Icons.sms,
          title: "Fetch chat details",
          supportingText: "Refresh title and participants",
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
        build: (context) => M3EListTile(
          icon: Icons.replay,
          title: "Sync messages",
          supportingText: "Sync messages for a time range",
          onTap: () async {
            final range = await showSyncTimeRangeDialog(context);
            if (range == null || !context.mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ChatSyncDialog(
                chat: chat,
                initialMessage: "Syncing messages...",
                start: range.start,
                end: range.end,
              ),
            );
          },
        ),
      ),
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          icon: Icons.note_outlined,
          title: "Download chat transcript",
          supportingText: kIsDesktop ? "Left click for text, right click for PDF" : "Tap for text, hold for PDF",
          onTap: () => _downloadTranscript(context, asPdf: false),
          onLongPress: () => _downloadTranscript(context, asPdf: true),
        ),
      ),
    ];

    return _group(context, "Content & data", rows);
  }

  Widget _buildDangerZoneGroup(BuildContext context) {
    final rows = <_OptionRow>[
      _OptionRow(
        enabled: !kIsWeb,
        build: (context) => M3EListTile(
          destructive: true,
          icon: Icons.delete_outlined,
          title: "Clear transcript",
          supportingText: "Delete all messages on this device",
          onTap: () {
            showBBDialog(
              context: context,
              title: "Are You Sure?",
              body:
                  'Clearing the transcript will permanently delete all messages in this chat. It will also prevent any previous messages from being loaded by the app, until you perform a full reset.',
              actions: [
                BBDialogAction(
                  text: "Cancel",
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                ),
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
        build: (context) => M3EListTile(
          destructive: true,
          icon: Icons.cancel_outlined,
          title: "Cancel outgoing messages",
          supportingText: "Cancel all messages queued to send",
          onTap: () => _showCancelConfirmation(context),
        ),
      ),
      _OptionRow(
        enabled: chat.handles.length > 2 &&
            SettingsSvc.settings.enablePrivateAPI.value &&
            SettingsSvc.serverDetails.supportsGroupChatManagement,
        build: (context) => M3EListTile(
          destructive: true,
          icon: Icons.logout,
          title: "Leave chat",
          supportingText: "Stop receiving messages from this group",
          onTap: () => _leaveChat(context),
        ),
      ),
    ];

    return _group(context, "Danger zone", rows, tone: M3ESectionTone.error);
  }

  void _showCancelConfirmation(BuildContext context) {
    showBBDialog(
      context: context,
      title: "Cancel Outgoing Messages?",
      body: 'This will cancel all messages currently waiting to be sent in this chat. They will be marked as failed.',
      actions: [
        BBDialogAction(
          text: "Keep Sending",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
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

  Future<void> _leaveChat(BuildContext context) async {
    await showAreYouSure(
      context,
      title: "Leave Chat?",
      content: const Text(
          "Are you sure you want to leave this chat? You will no longer receive messages from this group."),
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

  Future<void> _downloadTranscript(BuildContext context, {required bool asPdf}) async {
    final date = await showTimeframePicker("Select Timeframe", context, additionalTimeframes: {"6 Hours": 6});
    if (date == null || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BBProgressDialog(title: asPdf ? "Generating PDF..." : "Generating document..."),
    );
    final messages =
        (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true)).reversed.where((e) => e.dateCreated!.isAfter(date));
    if (messages.isEmpty) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      showSnackbar("Error", "No messages found!");
      return;
    }

    if (!asPdf) {
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
      final filePath = p.join(await FilesystemSvc.downloadsDirectory,
          "${chat.getTitle().replaceAll(RegExp(r'[<>:"/\\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt");
      File file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsString(lines.join('\n'));
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      showSnackbar("Success", "Saved transcript to the downloads folder");
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
        final attachments =
            m.dbAttachments.where((e) => e.guid != null && ["image/png", "image/jpg", "image/jpeg"].contains(e.mimeType));
        final files = attachments.map((e) => AttachmentsSvc.getContent(e, autoDownload: false)).whereType<PlatformFile>();
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
    doc.addPage(pw.MultiPage(
        maxPages: 1000,
        header: (pw.Context context) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(chat.getTitle(),
                textScaleFactor: 2,
                style: pw.Theme.of(context).defaultTextStyle.copyWith(fontWeight: pw.FontWeight.bold, font: font))),
        build: (pw.Context context) => [
              pw.Partitions(children: [
                pw.Partition(
                    child: pw.Table(
                        children: List.generate(
                            timestamps.length,
                            (index) => pw.TableRow(children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                    child: pw.Text(timestamps[index],
                                        style: pw.Theme.of(context).defaultTextStyle.copyWith(font: font)),
                                  ),
                                  pw.Container(
                                      child: pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                          child: content[index] is pw.MemoryImage
                                              ? pw.Image(content[index],
                                                  width: dimensions[index]!.width, height: dimensions[index]!.height)
                                              : pw.Text(content[index].toString(), style: pw.TextStyle(font: font))))
                                ])))),
              ]),
            ]));
    final now = DateTime.now().toLocal();
    final filePath = p.join(await FilesystemSvc.downloadsDirectory,
        "${chat.getTitle().replaceAll(RegExp(r'[<>:"/\\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.pdf");
    File file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(await doc.save());
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    showSnackbar("Success", "Saved transcript to the downloads folder");
  }
}
