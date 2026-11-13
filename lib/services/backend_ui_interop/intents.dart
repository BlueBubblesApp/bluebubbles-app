import 'package:bluebubbles/app/layouts/chat_creator/new_chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/models/models.dart' show MessageReplyContext;

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class OpenSettingsAction extends Action<OpenSettingsIntent> {
  OpenSettingsAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant OpenSettingsIntent intent) async {
    if (SettingsSvc.settings.finishedSetup.value) {
      final currentChat = ChatsSvc.activeChat?.chat;
      NavigationSvc.closeAllConversationView(context);
      await ChatsSvc.setAllInactive();
      await Navigator.of(Get.context!).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return const SettingsPage();
          },
        ),
      );
      if (currentChat != null) {
        if (SettingsSvc.settings.tabletMode.value) {
          NavigationSvc.pushAndRemoveUntil(
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
    if (SettingsSvc.settings.finishedSetup.value) {
      NavigationSvc.pushAndRemoveUntil(
        context,
        const NewChatCreator(),
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
    if (SettingsSvc.settings.finishedSetup.value) {
      NavigationSvc.pushLeft(
        context,
        const SearchView(),
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
    final chat = ChatsSvc.getChatState(chatGuid)?.chat;
    if (chat == null) return null;
    final service = maybeFindMessagesSvc(chatGuid);
    if (service == null) return null;
    final message = service.mostRecentReceived;
    if (message != null && SettingsSvc.settings.enablePrivateAPI.value) {
      final parts = service.getOrCreateState(message).parts;
      cvc(chat).replyToMessage = MessageReplyContext(message, parts.isEmpty ? 0 : parts.last.part);
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
    final chat = ChatsSvc.activeChat?.chat;
    if (chat != null) {
      final _chat = ChatsSvc.getNextChat(chat.guid);
      if (_chat != null) {
        NavigationSvc.pushAndRemoveUntil(
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
    final chat = ChatsSvc.activeChat?.chat;
    if (chat != null) {
      final _chat = ChatsSvc.getPreviousChat(chat.guid);
      if (_chat != null) {
        NavigationSvc.pushAndRemoveUntil(
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

class GoBackIntent extends Intent {
  const GoBackIntent();
}

class GoBackAction extends Action<GoBackIntent> {
  GoBackAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(covariant GoBackIntent intent) {
    if (SettingsSvc.settings.finishedSetup.value && !(Get.isDialogOpen ?? true)) {
      NavigationSvc.backConversationView(context);
    }
    return null;
  }
}
