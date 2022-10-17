import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/layouts/settings/settings_page.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class OpenSettingsAction extends Action<OpenSettingsIntent> {
  OpenSettingsAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenSettingsIntent intent) {
    if (ss.settings.finishedSetup.value) {
      Navigator.of(context).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return SettingsPage();
          },
        ),
      );
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
      EventDispatcher().emit("update-highlight", null);
      ns.pushAndRemoveUntil(
        context,
        ConversationView(
          isCreator: true,
        ),
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
  ReplyRecentAction(this.bloc);

  final MessageBloc bloc;

  @override
  Object? invoke(covariant ReplyRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      EventDispatcher().emit("focus-keyboard", message);
    }
    return null;
  }
}

class HeartRecentIntent extends Intent {
  const HeartRecentIntent();
}

class HeartRecentAction extends Action<HeartRecentIntent> {
  HeartRecentAction(this.bloc, this.chat);

  final MessageBloc bloc;
  final Chat chat;

  @override
  Object? invoke(covariant HeartRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      ActionHandler.sendReaction(chat, message, "love");
    }
    return null;
  }
}

class LikeRecentIntent extends Intent {
  const LikeRecentIntent();
}

class LikeRecentAction extends Action<LikeRecentIntent> {
  LikeRecentAction(this.bloc, this.chat);

  final MessageBloc bloc;
  final Chat chat;

  @override
  Object? invoke(covariant LikeRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      ActionHandler.sendReaction(chat, message, "like");
    }
    return null;
  }
}

class DislikeRecentIntent extends Intent {
  const DislikeRecentIntent();
}

class DislikeRecentAction extends Action<DislikeRecentIntent> {
  DislikeRecentAction(this.bloc, this.chat);

  final MessageBloc bloc;
  final Chat chat;

  @override
  Object? invoke(covariant DislikeRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      ActionHandler.sendReaction(chat, message, "dislike");
    }
    return null;
  }
}

class LaughRecentIntent extends Intent {
  const LaughRecentIntent();
}

class LaughRecentAction extends Action<LaughRecentIntent> {
  LaughRecentAction(this.bloc, this.chat);

  final MessageBloc bloc;
  final Chat chat;

  @override
  Object? invoke(covariant LaughRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      ActionHandler.sendReaction(chat, message, "laugh");
    }
    return null;
  }
}

class EmphasizeRecentIntent extends Intent {
  const EmphasizeRecentIntent();
}

class EmphasizeRecentAction extends Action<EmphasizeRecentIntent> {
  EmphasizeRecentAction(this.bloc, this.chat);

  final MessageBloc bloc;
  final Chat chat;

  @override
  Object? invoke(covariant EmphasizeRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      ActionHandler.sendReaction(chat, message, "emphasize");
    }
    return null;
  }
}

class QuestionRecentIntent extends Intent {
  const QuestionRecentIntent();
}

class QuestionRecentAction extends Action<QuestionRecentIntent> {
  QuestionRecentAction(this.bloc, this.chat);

  final MessageBloc bloc;
  final Chat chat;

  @override
  Object? invoke(covariant QuestionRecentIntent intent) async {
    final message = bloc.messages.values.firstWhereOrNull((element) => element.associatedMessageGuid == null);
    if (message != null && ss.settings.enablePrivateAPI.value) {
      ActionHandler.sendReaction(chat, message, "question");
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
    final chat = ChatManager().activeChat?.chat;
    if (chat != null) {
      final index = ChatBloc().chats.indexWhere((e) => e.guid == chat.guid);
      if (index > -1 && index < ChatBloc().chats.length - 1) {
        final _chat = ChatBloc().chats[index + 1];
        ns.pushAndRemoveUntil(
          context,
          ConversationView(
            chat: _chat,
          ),
          (route) => route.isFirst,
        );

        ChatManager().setActiveChat(_chat);
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
    final chat = ChatManager().activeChat?.chat;
    if (chat != null) {
      final index = ChatBloc().chats.indexWhere((e) => e.guid == chat.guid);
      if (index > 0 && index < ChatBloc().chats.length) {
        final _chat = ChatBloc().chats[index - 1];
        ns.pushAndRemoveUntil(
          context,
          ConversationView(
            chat: _chat,
          ),
          (route) => route.isFirst,
        );
        
        ChatManager().setActiveChat(_chat);
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
