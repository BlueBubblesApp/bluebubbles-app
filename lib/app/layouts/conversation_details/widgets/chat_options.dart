import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/chat_sync_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_io/io.dart';

class ChatOptions extends StatefulWidget {
  const ChatOptions({super.key, required this.chatGuid});

  final String chatGuid;

  @override
  OptimizedState createState() => _ChatOptionsState();
}

class _ChatOptionsState extends OptimizedState<ChatOptions> {
  Chat get chat => GlobalChatService.getChat(widget.chatGuid)!.chat;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdaptiveTheme.of(context).theme,
      child: SliverToBoxAdapter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
              child: Text("OPTIONS & ACTIONS",
                  style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
            ),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                if (!kIsWeb && !kIsDesktop && (fs.androidInfo?.version.sdkInt ?? 0) >= 30)
                  SettingsTile(
                    title: "Notification Settings",
                    subtitle: "Customize notification sounds, importance, and more for this specific chat",
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: Icon(
                        iOS ? CupertinoIcons.bell : Icons.notifications_on,
                      ),
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      await mcs.invokeMethod("open-conversation-notification-settings",
                          {"channel_id": chat.guid, "display_name": chat.getTitle()});
                    },
                  ),
                if (!kIsWeb)
                  SettingsTile(
                    title: "Change Chat Avatar",
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: Icon(
                        ss.settings.skin.value == Skins.iOS ? CupertinoIcons.person : Icons.person_outlined,
                      ),
                    ),
                    onTap: () {
                      if (chat.customAvatarPath != null) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                title: Text("Custom Avatar", style: context.theme.textTheme.titleLarge),
                                content: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("You already have a custom avatar for this chat. What would you like to do?",
                                        style: context.theme.textTheme.bodyLarge),
                                  ],
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Cancel",
                                        style: context.theme.textTheme.bodyLarge!
                                            .copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Reset",
                                        style: context.theme.textTheme.bodyLarge!
                                            .copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      File file = File(chat.customAvatarPath!);
                                      file.delete();
                                      chat.customAvatarPath = null;
                                      chat.save(updateCustomAvatarPath: true);
                                      Get.back();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Set New",
                                        style: context.theme.textTheme.bodyLarge!
                                            .copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Get.to(() => AvatarCrop(chat: chat));
                                    },
                                  ),
                                ]);
                          },
                        );
                      } else {
                        Get.to(() => AvatarCrop(chat: chat));
                      }
                    },
                  ),
                if (iOS)
                  SettingsTile(
                      title: "View Bookmarks",
                      subtitle: "See your bookmarked messages",
                      backgroundColor: tileColor,
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: Icon(iOS ? CupertinoIcons.bookmark : Icons.bookmark),
                      ),
                      onTap: () async {
                        showBookmarksThread(cvc(widget.chatGuid), context);
                      }),
                SettingsTile(
                    title: "Fetch Chat Details",
                    subtitle: "Get the latest chat title and participants from the server",
                    backgroundColor: tileColor,
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: Icon(iOS ? CupertinoIcons.chat_bubble : Icons.sms),
                    ),
                    onTap: () async {
                      await cm.fetchChat(chat.guid);
                      showSnackbar("Notice", "Fetched details!");
                    }),
                SettingsTile(
                  title: "Fetch More Messages",
                  subtitle: "Fetches up to 100 messages after the last message stored locally",
                  isThreeLine: true,
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 15.0),
                    child: Icon(iOS ? CupertinoIcons.cloud_download : Icons.file_download),
                  ),
                  onTap: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => ChatSyncDialog(
                        chat: chat,
                        withOffset: true,
                        initialMessage: "Fetching more messages...",
                        limit: 100,
                      ),
                    );
                  },
                ),
                SettingsTile(
                  title: "Sync Last 25 Messages",
                  subtitle: "Resyncs the 25 most recent messages from the server",
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 15.0),
                    child: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.replay),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          ChatSyncDialog(chat: chat, initialMessage: "Resyncing messages...", limit: 25),
                    );
                  },
                ),
                if (!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value) const SettingsDivider(),
                if (!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value)
                  SettingsSwitch(
                    title: "Send Typing Indicators",
                    initialVal: chat.autoSendTypingIndicators ?? ss.settings.privateSendTypingIndicators.value,
                    onChanged: (value) {
                      chat.toggleAutoType(value);
                      setState(() {});
                    },
                    backgroundColor: tileColor,
                  ),
                if (!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value)
                  SettingsSwitch(
                      title: "Follow Global Setting",
                      subtitle:
                          "Typing Indicators ${ss.settings.privateSendTypingIndicators.value ? "Enabled" : "Disabled"}",
                      initialVal: chat.autoSendTypingIndicators == null,
                      onChanged: (value) {
                        if (!value) {
                          chat.toggleAutoType(ss.settings.privateSendTypingIndicators.value);
                        } else {
                          chat.toggleAutoType(null);
                        }
                        setState(() {});
                      }),
                if (!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value) const SettingsDivider(),
                if (!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value)
                  SettingsSwitch(
                    title: "${ss.settings.privateManualMarkAsRead.value ? "Automatically " : ""}Send Read Receipts",
                    initialVal: chat.autoSendReadReceipts ?? ss.settings.privateMarkChatAsRead.value,
                    onChanged: (value) {
                      chat.toggleAutoRead(value);
                      setState(() {});
                    },
                    backgroundColor: tileColor,
                  ),
                if (!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value)
                  SettingsSwitch(
                    title: "Follow Global Setting",
                    subtitle:
                        "${ss.settings.privateManualMarkAsRead.value ? "Automatic " : ""}Read Receipts ${ss.settings.privateMarkChatAsRead.value ? "Enabled" : "Disabled"}",
                    initialVal: chat.autoSendReadReceipts == null,
                    onChanged: (value) {
                      if (!value) {
                        chat.toggleAutoRead(ss.settings.privateMarkChatAsRead.value);
                      } else {
                        chat.toggleAutoRead(null);
                      }
                      setState(() {});
                    },
                  ),
                if ((!kIsWeb && !chat.isGroup && ss.settings.enablePrivateAPI.value) || chat.isGroup)
                  const SettingsDivider(),
                if (chat.isGroup)
                  SettingsSwitch(
                    title: "Lock Chat Name",
                    subtitle: "Keep the current chat name on this device, even if someone else in the chat changes it",
                    initialVal: chat.lockChatName,
                    onChanged: (value) {
                      chat.lockChatName = value;
                      chat.save(updateLockChatName: true);
                      setState(() {});
                    },
                  ),
                if (chat.isGroup)
                  SettingsSwitch(
                    title: "Lock Chat Icon",
                    subtitle: "Keep the current chat icon on this device, even if someone else in the chat changes it",
                    initialVal: chat.lockChatIcon,
                    onChanged: (value) {
                      chat.lockChatIcon = value;
                      chat.save(updateLockChatIcon: true);
                      setState(() {});
                    },
                  ),
                if (chat.isGroup) const SettingsDivider(),
                if (!kIsWeb)
                  SettingsSwitch(
                    title: "Pin Conversation",
                    initialVal: chat.isPinned!,
                    onChanged: (value) {
                      chat.togglePin(!chat.isPinned!);
                      setState(() {});
                    },
                    backgroundColor: tileColor,
                  ),
                if (!kIsWeb)
                  SettingsSwitch(
                    title: "Mute Conversation",
                    initialVal: chat.muteType == "mute",
                    onChanged: (value) {
                      chat.toggleMute(value);
                      setState(() {});
                    },
                    backgroundColor: tileColor,
                  ),
                if (!kIsWeb)
                  SettingsSwitch(
                    title: "Archive Conversation",
                    initialVal: chat.isArchived!,
                    onChanged: (value) {
                      chat.toggleArchived(value);
                      setState(() {});
                    },
                    backgroundColor: tileColor,
                  ),
                if (!kIsWeb)
                  SettingsTile(
                    title: "Clear Transcript",
                    subtitle: "Delete all messages for this chat on this device",
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                              backgroundColor: context.theme.colorScheme.properSurface,
                              title: Text("Are You Sure?", style: context.theme.textTheme.titleLarge),
                              content: Text(
                                'Clearing the transcript will permanently delete all messages in this chat. It will also prevent any previous messages from being loaded by the app, until you perform a full reset.',
                                style: context.theme.textTheme.bodyLarge,
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text("Cancel",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: Text("Yes",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    chat.clearTranscript();
                                    eventDispatcher.emit("refresh-messagebloc", {"chatGuid": chat.guid});
                                  },
                                ),
                              ]);
                        },
                      );
                    },
                  ),
                if (!kIsWeb)
                  SettingsTile(
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
                      final date =
                          await showTimeframePicker("Select Timeframe", context, additionalTimeframes: {"6 Hours": 6});
                      if (date == null) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Generating document...", style: context.theme.textTheme.titleLarge),
                          content: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(
                                height: 15.0,
                              ),
                              buildProgressIndicator(context),
                            ],
                          ),
                          backgroundColor: context.theme.colorScheme.properSurface,
                        ),
                        barrierDismissible: false,
                      );
                      final messages = (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true))
                          .reversed
                          .where((e) => e.dateCreated.isAfter(date));
                      if (messages.isEmpty) {
                        Get.back();
                        showSnackbar("Error", "No messages found!");
                        return;
                      }
                      final List<String> lines = [];
                      for (Message m in messages) {
                        final readStr = m.dateRead != null ? "Read: ${buildFullDate(m.dateRead!)}, " : "";
                        final deliveredStr =
                            m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
                        final sentStr = "Sent: ${buildFullDate(m.dateCreated)}";
                        final text = MessageHelper.getNotificationText(m, withSender: true);
                        final line = "($readStr$deliveredStr$sentStr) $text";
                        lines.add(line);
                      }
                      final now = DateTime.now().toLocal();
                      String filePath = "/storage/emulated/0/Download/";
                      if (kIsDesktop) {
                        filePath = (await getDownloadsDirectory())!.path;
                      }
                      filePath = p.join(filePath,
                          "${(chat.title ?? "Unknown Chat").replaceAll(RegExp(r'[<>:"/\\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt");
                      File file = File(filePath);
                      await file.create(recursive: true);
                      await file.writeAsString(lines.join('\n'));
                      Get.back();
                      showSnackbar("Success", "Saved transcript to the downloads folder");
                    },
                    onLongPress: () async {
                      final date =
                          await showTimeframePicker("Select Timeframe", context, additionalTimeframes: {"6 Hours": 6});
                      if (date == null) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Generating PDF...", style: context.theme.textTheme.titleLarge),
                          content: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const SizedBox(
                                  height: 15.0,
                                ),
                                buildProgressIndicator(context),
                              ]),
                          backgroundColor: context.theme.colorScheme.properSurface,
                        ),
                        barrierDismissible: false,
                      );
                      final messages = (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true))
                          .reversed
                          .where((e) => e.dateCreated.isAfter(date));
                      if (messages.isEmpty) {
                        Get.back();
                        showSnackbar("Error", "No messages found!");
                        return;
                      }
                      final doc = pw.Document();
                      final List<String> timestamps = [];
                      final List<dynamic> content = [];
                      final List<Size?> dimensions = [];
                      for (Message m in messages) {
                        final readStr = m.dateRead != null ? "Read: ${buildFullDate(m.dateRead!)}, " : "";
                        final deliveredStr =
                            m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
                        final sentStr = "Sent: ${buildFullDate(m.dateCreated)}";
                        if (m.hasAttachments) {
                          final attachments = m.attachments.where(
                              (e) => e?.guid != null && ["image/png", "image/jpg", "image/jpeg"].contains(e!.mimeType));
                          final files =
                              attachments.map((e) => as.getContent(e!, autoDownload: false)).whereType<PlatformFile>();
                          if (files.isNotEmpty) {
                            for (PlatformFile f in files) {
                              final a = attachments.firstWhere((e) => e!.transferName == f.name);
                              timestamps.add(readStr + deliveredStr + sentStr);
                              content.add(pw.MemoryImage(await File(f.path!).readAsBytes()));
                              final aspectRatio = (a!.width ?? 150.0) / (a.height ?? 150.0);
                              dimensions.add(Size(400, aspectRatio * 400));
                            }
                          }
                          timestamps.add(readStr + deliveredStr + sentStr);
                          content.add(MessageHelper.getNotificationText(m, withSender: true));
                          dimensions.add(null);
                        } else {
                          timestamps.add(readStr + deliveredStr + sentStr);
                          content.add(MessageHelper.getNotificationText(m, withSender: true));
                          dimensions.add(null);
                        }
                      }
                      final font = await PdfGoogleFonts.openSansRegular();
                      doc.addPage(pw.MultiPage(
                          maxPages: 1000,
                          header: (pw.Context context) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 10),
                              child: pw.Text(chat.title ?? "Unknown Chat",
                                  textScaleFactor: 2,
                                  style: pw.Theme.of(context)
                                      .defaultTextStyle
                                      .copyWith(fontWeight: pw.FontWeight.bold, font: font))),
                          build: (pw.Context context) => [
                                pw.Partitions(children: [
                                  pw.Partition(
                                      child: pw.Table(
                                          children: List.generate(
                                              timestamps.length,
                                              (index) => pw.TableRow(children: [
                                                    pw.Padding(
                                                      padding:
                                                          const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                                      child: pw.Text(timestamps[index],
                                                          style: pw.Theme.of(context)
                                                              .defaultTextStyle
                                                              .copyWith(font: font)),
                                                    ),
                                                    pw.Container(
                                                        child: pw.Padding(
                                                            padding: const pw.EdgeInsets.symmetric(
                                                                horizontal: 3, vertical: 10),
                                                            child: content[index] is pw.MemoryImage
                                                                ? pw.Image(content[index],
                                                                    width: dimensions[index]!.width,
                                                                    height: dimensions[index]!.height)
                                                                : pw.Text(content[index].toString(),
                                                                    style: pw.TextStyle(font: font))))
                                                  ])))),
                                ]),
                              ]));
                      final now = DateTime.now().toLocal();
                      String filePath = "/storage/emulated/0/Download/";
                      if (kIsDesktop) {
                        filePath = (await getDownloadsDirectory())!.path;
                      }
                      filePath = p.join(filePath,
                          "${(chat.title ?? "Unknown Chat").replaceAll(RegExp(r'[<>:"/\\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.pdf");
                      File file = File(filePath);
                      await file.create(recursive: true);
                      await file.writeAsBytes(await doc.save());
                      Get.back();
                      showSnackbar("Success", "Saved transcript to the downloads folder");
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
