import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachments_loader.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_info.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_options.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_findmy_card.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_list.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/documents/documents_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/links/links_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/locations/locations_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/media/media_grid_section.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;

  const ConversationDetails({super.key, required this.chat});

  @override
  State<ConversationDetails> createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<ConversationDetails> with WidgetsBindingObserver, ThemeHelpers {
  List<Attachment> media = <Attachment>[];
  List<Attachment> docs = <Attachment>[];
  List<Attachment> locations = <Attachment>[];
  late Chat chat = widget.chat;
  final RxList<String> selected = <String>[].obs;
  bool isLoadingAttachments = true;

  @override
  void initState() {
    super.initState();
    ChatsSvc.setActiveToDead();
  }

  @override
  void dispose() {
    if (ChatsSvc.activeChat != null) {
      ChatsSvc.setActiveToAlive();
      cvc(ChatsSvc.activeChat!.chat).lastFocusedNode.requestFocus();
    }
    super.dispose();
  }

  void onAttachmentsLoaded(
      List<Attachment> loadedMedia, List<Attachment> loadedDocs, List<Attachment> loadedLocations) {
    if (mounted) {
      setState(() {
        media = loadedMedia;
        docs = loadedDocs;
        locations = loadedLocations;
        isLoadingAttachments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getOrCreateChatState(chat);
    return ChatStateScope(
      chatState: chatState,
      child: Obx(() {
        final isDark = ThemeSvc.inDarkMode(context);
        chatState.themeVersion.value;
        final themeName = isDark ? chatState.customThemeDark.value : chatState.customThemeLight.value;
        final baseTheme = ThemeStruct.resolveByName(themeName, isDark ? Brightness.dark : Brightness.light).data;

        // Compute scaffold colors from baseTheme before copyWith modifies colorScheme.surface.
        final hasWindowEffect = SettingsSvc.settings.windowEffect.value != WindowEffect.disabled;
        final reverseMapping = SettingsSvc.settings.skin.value == Skins.Material && isDark;
        final rawHeaderColor = (isDark ? baseTheme.colorScheme.surface : baseTheme.colorScheme.surfaceContainerHighest)
            .withAlpha(hasWindowEffect ? 20 : 255);
        final rawTileColor = (isDark ? baseTheme.colorScheme.surfaceContainerHighest : baseTheme.colorScheme.surface)
            .withAlpha(hasWindowEffect ? 100 : 255);
        final scaffoldHeaderColor = reverseMapping ? rawTileColor : rawHeaderColor;
        final scaffoldTileColor = reverseMapping ? rawHeaderColor : rawTileColor;

        final bubbleColors = baseTheme.extensions[BubbleColors] as BubbleColors?;
        final bubbleColor = chat.isIMessage
            ? bubbleColors?.iMessageBubbleColor ?? baseTheme.colorScheme.iMessageBubble
            : bubbleColors?.smsBubbleColor ?? baseTheme.colorScheme.smsBubble;
        final onBubbleColor = chat.isIMessage
            ? bubbleColors?.oniMessageBubbleColor ?? baseTheme.colorScheme.oniMessageBubble
            : bubbleColors?.onSmsBubbleColor ?? baseTheme.colorScheme.onSmsBubble;
        final useGeneratedThemeSurface = themeName != null
            ? ThemesService.isGeneratedMaterialThemeName(themeName)
            : ThemeSvc.isMaterialYouActive(context);

        return Theme(
            data: baseTheme.copyWith(
              primaryColor: bubbleColor,
              colorScheme: baseTheme.colorScheme.copyWith(
                primary: bubbleColor,
                onPrimary: onBubbleColor,
                surface: useGeneratedThemeSurface ? null : bubbleColors?.receivedBubbleColor,
                onSurface: useGeneratedThemeSurface ? null : bubbleColors?.onReceivedBubbleColor,
              ),
            ),
            child: Obx(() => SettingsScaffold(
                  headerColor: scaffoldHeaderColor,
                  title: "Details",
                  tileColor: scaffoldTileColor,
                  initialHeader: null,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  actions: [
                    Obx(() {
                      if (selected.isNotEmpty) {
                        return IconButton(
                          icon: Icon(iOS ? CupertinoIcons.xmark : Icons.close,
                              color: context.theme.colorScheme.onSurface),
                          onPressed: () {
                            selected.clear();
                          },
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    Obx(() {
                      if (selected.isNotEmpty) {
                        return IconButton(
                          icon: Icon(iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                              color: context.theme.colorScheme.onSurface),
                          onPressed: () {
                            final attachments = media.where((e) => selected.contains(e.guid!));
                            for (Attachment a in attachments) {
                              final file = AttachmentsSvc.getContent(a, autoDownload: false);
                              if (file is PlatformFile) {
                                AttachmentsSvc.saveToDisk(file);
                              }
                            }
                          },
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                  ],
                  bodySlivers: [
                    SliverToBoxAdapter(
                      child: ChatInfo(chat: chat),
                    ),
                    ParticipantsFindMyMapCard(chat: chat),
                    ParticipantsList(chat: chat),
                    // Hidden widget that loads attachments in the background
                    SliverToBoxAdapter(
                      child: AttachmentsLoader(
                        chat: chat,
                        onAttachmentsLoaded: onAttachmentsLoaded,
                      ),
                    ),
                    if (chat.handles.length > 2 &&
                        SettingsSvc.settings.enablePrivateAPI.value &&
                        SettingsSvc.serverDetails.supportsGroupChatManagement)
                      SliverToBoxAdapter(
                        child: Builder(builder: (context) {
                          return ListTile(
                            mouseCursor: MouseCursor.defer,
                            title: Text("Leave ${iOS ? "Chat" : "chat"}",
                                style: context.theme.textTheme.bodyLarge!
                                    .copyWith(color: context.theme.colorScheme.error)),
                            leading: Container(
                              width: 40 * SettingsSvc.settings.avatarScale.value,
                              height: 40 * SettingsSvc.settings.avatarScale.value,
                              decoration: BoxDecoration(
                                  color: !iOS ? null : context.theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  border: iOS ? null : Border.all(color: context.theme.colorScheme.error, width: 3)),
                              child: Icon(Icons.error_outline, color: context.theme.colorScheme.error, size: 20),
                            ),
                            onTap: () async {
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
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                                          title: Text(
                                            "Leaving chat...",
                                            style: context.theme.textTheme.titleLarge,
                                          ),
                                          content: SizedBox(
                                            height: 70,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                  final response = await HttpSvc.chat.leave(chat.guid);
                                  if (!context.mounted) return;
                                  if (response.statusCode == 200) {
                                    Navigator.of(context, rootNavigator: true).pop();
                                    showSnackbar("Notice", "Left chat successfully!");
                                  } else {
                                    Navigator.of(context, rootNavigator: true).pop();
                                    showSnackbar("Error", "Failed to leave chat!");
                                  }
                                },
                              );
                            },
                          );
                        }),
                      ),
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    ChatOptions(chat: chat),
                    MediaGridSection(chat: chat, media: media, selected: selected, isLoading: isLoadingAttachments),
                    LinksSection(chat: chat),
                    LocationsSection(chat: chat, locations: locations, isLoading: isLoadingAttachments),
                    DocumentsSection(chat: chat, docs: docs, isLoading: isLoadingAttachments),
                    const SliverPadding(
                      padding: EdgeInsets.only(top: 50),
                    ),
                  ],
                )));
      }),
    );
  }
}
