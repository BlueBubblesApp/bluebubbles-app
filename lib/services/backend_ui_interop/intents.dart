import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class OpenSettingsAction extends Action<OpenSettingsIntent> {
  OpenSettingsAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenSettingsIntent intent) async {
    if (ss.settings.finishedSetup.value) {
      final currentChat = GlobalChatService.activeGuid.value;
      ns.closeAllConversationView(context);
      await GlobalChatService.closeActiveChat();
      await Navigator.of(Get.context!).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return SettingsPage();
          },
        ),
      );
      if (currentChat != null) {
        if (ss.settings.tabletMode.value) {
          GlobalChatService.openChat(currentChat, context: context);
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
  ReplyRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant ReplyRecentIntent intent) async {
    final message = ms(chatGuid).mostRecentReceived;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      final parts = mwc(message).parts;
      cvc(chatGuid).replyToMessage = Tuple2(message, parts.length - 1);
    }
    return null;
  }
}

class HeartRecentIntent extends Intent {
  const HeartRecentIntent();
}

class HeartRecentAction extends Action<HeartRecentIntent> {
  HeartRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant HeartRecentIntent intent) async {
    final message = ms(chatGuid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chatGuid, message, ReactionTypes.LOVE);
    }
    return null;
  }
}

class LikeRecentIntent extends Intent {
  const LikeRecentIntent();
}

class LikeRecentAction extends Action<LikeRecentIntent> {
  LikeRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant LikeRecentIntent intent) async {
    final message = ms(chatGuid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chatGuid, message, ReactionTypes.LIKE);
    }
    return null;
  }
}

class DislikeRecentIntent extends Intent {
  const DislikeRecentIntent();
}

class DislikeRecentAction extends Action<DislikeRecentIntent> {
  DislikeRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant DislikeRecentIntent intent) async {
    final message = ms(chatGuid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chatGuid, message, ReactionTypes.DISLIKE);
    }
    return null;
  }
}

class LaughRecentIntent extends Intent {
  const LaughRecentIntent();
}

class LaughRecentAction extends Action<LaughRecentIntent> {
  LaughRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant LaughRecentIntent intent) async {
    final message = ms(chatGuid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chatGuid, message, ReactionTypes.LAUGH);
    }
    return null;
  }
}

class EmphasizeRecentIntent extends Intent {
  const EmphasizeRecentIntent();
}

class EmphasizeRecentAction extends Action<EmphasizeRecentIntent> {
  EmphasizeRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant EmphasizeRecentIntent intent) async {
    final message = ms(chatGuid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chatGuid, message, ReactionTypes.EMPHASIZE);
    }
    return null;
  }
}

class QuestionRecentIntent extends Intent {
  const QuestionRecentIntent();
}

class QuestionRecentAction extends Action<QuestionRecentIntent> {
  QuestionRecentAction(this.chatGuid);

  final String chatGuid;

  @override
  Object? invoke(covariant QuestionRecentIntent intent) async {
    final message = ms(chatGuid).mostRecent;
    if (message != null && ss.settings.enablePrivateAPI.value) {
      _sendReactionHelper(chatGuid, message, ReactionTypes.QUESTION);
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
    final chatGuid = GlobalChatService.activeGuid.value;
    if (chatGuid != null) {
      GlobalChatService.openNextChat(chatGuid, context: context);
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
    final chatGuid = GlobalChatService.activeGuid.value;
    if (chatGuid != null) {
      GlobalChatService.openPreviousChat(chatGuid, context: context);
    }

    return null;
  }
}

class OpenChatDetailsIntent extends Intent {
  const OpenChatDetailsIntent();
}

class OpenChatDetailsAction extends Action<OpenChatDetailsIntent> {
  OpenChatDetailsAction(this.context, this.chatGuid);

  final BuildContext context;
  final String chatGuid;

  @override
  Object? invoke(covariant OpenChatDetailsIntent intent) {
    GlobalChatService.openChatDetails(chatGuid, context: context);
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

void _sendReactionHelper(String chatGuid, Message selected, String t) {
  final c = GlobalChatService.getChat(chatGuid)!.chat;
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