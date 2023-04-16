import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class OpenSettingsAction extends Action<OpenSettingsIntent> {
  OpenSettingsAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenSettingsIntent intent) async {
    if (ss.settings.finishedSetup.value) {
      final currentChat = cm.activeChat?.chat;
      ns.closeAllConversationView(context);
      await cm.setAllInactive();
      await Navigator.of(Get.context!).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return SettingsPage();
          },
        ),
      );
      if (currentChat != null) {
        if (ss.settings.tabletMode.value) {
          ns.pushAndRemoveUntil(
            context,
            ConversationView(
              chat: currentChat,
            ),
                (route) => route.isFirst,
          );
        } else {
          cvc(currentChat).close();
        }
      }
    }
    return null;
  }
}

class OpenNewChatCreatorIntent extends Intent {
  const OpenNewChatCreatorIntent();
}

class OpenNewChatCreatorAction extends Action<OpenNewChatCreatorIntent> {
  OpenNewChatCreatorAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenNewChatCreatorIntent intent) {
    if (ss.settings.finishedSetup.value) {
      eventDispatcher.emit("update-highlight", null);
      ns.pushAndRemoveUntil(
        context,
        const ChatCreator(),
        (route) => route.isFirst,
      );
    }
    return null;
  }
}

class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

class OpenSearchAction extends Action<OpenSearchIntent> {
  OpenSearchAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenSearchIntent intent) async {
    if (ss.settings.finishedSetup.value) {
      ns.pushLeft(
        context,
        SearchView(),
      );
    }
    return null;
  }
}

class ReplyRecentIntent extends Intent {
  const ReplyRecentIntent();
}

class ReplyRecentAction extends Action<ReplyRecentIntent> {
  ReplyRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant ReplyRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      eventDispatcher.emit("focus-keyboard", message);
    }
    return null;
  }
}

class HeartRecentIntent extends Intent {
  const HeartRecentIntent();
}

class HeartRecentAction extends Action<HeartRecentIntent> {
  HeartRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant HeartRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chat, message, ReactionTypes.LOVE);
    }
    return null;
  }
}

class LikeRecentIntent extends Intent {
  const LikeRecentIntent();
}

class LikeRecentAction extends Action<LikeRecentIntent> {
  LikeRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant LikeRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chat, message, ReactionTypes.LIKE);
    }
    return null;
  }
}

class DislikeRecentIntent extends Intent {
  const DislikeRecentIntent();
}

class DislikeRecentAction extends Action<DislikeRecentIntent> {
  DislikeRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant DislikeRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chat, message, ReactionTypes.DISLIKE);
    }
    return null;
  }
}

class LaughRecentIntent extends Intent {
  const LaughRecentIntent();
}

class LaughRecentAction extends Action<LaughRecentIntent> {
  LaughRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant LaughRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chat, message, ReactionTypes.LAUGH);
    }
    return null;
  }
}

class EmphasizeRecentIntent extends Intent {
  const EmphasizeRecentIntent();
}

class EmphasizeRecentAction extends Action<EmphasizeRecentIntent> {
  EmphasizeRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant EmphasizeRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chat, message, ReactionTypes.EMPHASIZE);
    }
    return null;
  }
}

class QuestionRecentIntent extends Intent {
  const QuestionRecentIntent();
}

class QuestionRecentAction extends Action<QuestionRecentIntent> {
  QuestionRecentAction(this.chat);

  final Chat chat;

  @override
  Object? invoke(covariant QuestionRecentIntent intent) async {
    final message = ms(chat.guid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chat, message, ReactionTypes.QUESTION);
    }
    return null;
  }
}

class OpenNextChatIntent extends Intent {
  const OpenNextChatIntent();
}

class OpenNextChatAction extends Action<OpenNextChatIntent> {
  OpenNextChatAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenNextChatIntent intent) {
    final chat = cm.activeChat?.chat;
    if (chat != null) {
      final index = chats.chats.indexWhere((e) => e.guid == chat.guid);
      if (index > -1 && index < chats.chats.length - 1) {
        final _chat = chats.chats[index + 1];
        ns.pushAndRemoveUntil(
          context,
          ConversationView(
            chat: _chat,
          ),
          (route) => route.isFirst,
        );
      }
    }
    return null;
  }
}

class OpenPreviousChatIntent extends Intent {
  const OpenPreviousChatIntent();
}

class OpenPreviousChatAction extends Action<OpenPreviousChatIntent> {
  OpenPreviousChatAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenPreviousChatIntent intent) {
    final chat = cm.activeChat?.chat;
    if (chat != null) {
      final index = chats.chats.indexWhere((e) => e.guid == chat.guid);
      if (index > 0 && index < chats.chats.length) {
        final _chat = chats.chats[index - 1];
        ns.pushAndRemoveUntil(
          context,
          ConversationView(
            chat: _chat,
          ),
          (route) => route.isFirst,
        );
      }
    }
    return null;
  }
}

class OpenChatDetailsIntent extends Intent {
  const OpenChatDetailsIntent();
}

class OpenChatDetailsAction extends Action<OpenChatDetailsIntent> {
  OpenChatDetailsAction(this.context, this.chat);

  final BuildContext context;
  final Chat chat;

  @override
  Object? invoke(covariant OpenChatDetailsIntent intent) {
    ns.push(
      context,
      ConversationDetails(chat: chat),
    );
    return null;
  }
}

class StartIncrementalSyncIntent extends Intent {
  const StartIncrementalSyncIntent();
}

class StartIncrementalSyncAction extends Action<StartIncrementalSyncIntent> {
  @override
  Object? invoke(covariant StartIncrementalSyncIntent intent) {
    if (ss.settings.finishedSetup.value) {
      sync.startIncrementalSync();
    }
    return null;
  }
}

class GoBackIntent extends Intent {
  const GoBackIntent();
}

class GoBackAction extends Action<GoBackIntent> {
  GoBackAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant GoBackIntent intent) {
    if (ss.settings.finishedSetup.value && !(Get.isDialogOpen ?? true)) {
      ns.backConversationView(context);
    }
    return null;
  }
}

void _sendReactionHelper(Chat c, Message selected, String t) {
  outq.queue(OutgoingItem(
    type: QueueType.sendMessage,
    chat: c,
    message: Message(
      associatedMessageGuid: selected.guid,
      associatedMessageType: t,
      dateCreated: DateTime.now(),
      hasAttachments: false,
      isFromMe: true,
      handleId: 0,
    ),
    selected: selected,
    reaction: t,
  ));
}