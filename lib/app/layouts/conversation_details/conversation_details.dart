import 'package:bluebubbles/app/layouts/conversation_details/material/chat_detail_theme.dart';
import 'package:bluebubbles/app/layouts/conversation_details/material/material_chat_header.dart';
import 'package:bluebubbles/app/layouts/conversation_details/material/material_chat_options.dart';
import 'package:bluebubbles/app/layouts/conversation_details/material/material_participants_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachments_loader.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_info.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_options.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/documents/documents_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/links/links_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/locations/locations_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/media/media_grid_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/participants_list.dart';
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
      final controller = cvc(ChatsSvc.activeChat!.chat);
      if (!controller.skipComposerFocusOnReturn) {
        controller.lastFocusedNode.requestFocus();
      }
    }
    super.dispose();
  }

  void onAttachmentsLoaded(
    List<Attachment> loadedMedia,
    List<Attachment> loadedDocs,
    List<Attachment> loadedLocations,
  ) {
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
        final chatDetailTheme = ChatDetailTheme.resolve(context, chat);

        return Theme(
          data: chatDetailTheme.theme,
          child: SettingsScaffold(
            headerColor: chatDetailTheme.headerColor,
            title: "Details",
            tileColor: chatDetailTheme.tileColor,
            initialHeader: null,
            iosSubtitle: iosSubtitle,
            materialSubtitle: materialSubtitle,
            minimalAppBar: true,
            actions: [
              Obx(() {
                if (selected.isNotEmpty) {
                  return IconButton(
                    icon: Icon(iOS ? CupertinoIcons.xmark : Icons.close, color: context.theme.colorScheme.onSurface),
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
                    icon: Icon(
                      iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                      color: context.theme.colorScheme.onSurface,
                    ),
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
                child: SettingsSvc.settings.skin.value == Skins.iOS
                    ? ChatInfo(chat: chat)
                    : ExpressiveChatHeader(chat: chat),
              ),
              SettingsSvc.settings.skin.value == Skins.iOS
                  ? ParticipantsList(chat: chat)
                  : ExpressiveParticipantsSection(chat: chat),
              // Hidden widget that loads attachments in the background
              SliverToBoxAdapter(
                child: AttachmentsLoader(chat: chat, onAttachmentsLoaded: onAttachmentsLoaded),
              ),
              SliverPadding(padding: EdgeInsets.symmetric(vertical: SettingsSvc.settings.skin.value == Skins.iOS ? 0 : 5)),
              SettingsSvc.settings.skin.value == Skins.iOS
                  ? ChatOptions(chat: chat)
                  : ExpressiveChatOptions(chat: chat),
              MediaGridSection(chat: chat, media: media, selected: selected, isLoading: isLoadingAttachments),
              LinksSection(chat: chat),
              LocationsSection(chat: chat, locations: locations, isLoading: isLoadingAttachments),
              DocumentsSection(chat: chat, docs: docs, isLoading: isLoadingAttachments),
              const SliverPadding(padding: EdgeInsets.only(top: 50)),
            ],
          ),
        );
      }),
    );
  }
}
