import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:bluebubbles/services/ui/message/messages_service.dart';
import 'package:flutter/widgets.dart';

class MessagePopupServerDetails {
  final bool minSierra;
  final bool minBigSur;
  final bool supportsOriginalDownload;

  const MessagePopupServerDetails({
    required this.minSierra,
    required this.minBigSur,
    required this.supportsOriginalDownload,
  });
}

class MessagePopupActionContext {
  final BuildContext context;
  final BuildContext widthContext;
  final ConversationViewController cvController;
  final MessageState messageState;
  final Message message;
  final MessagePart part;
  final Chat chat;
  final MessagesService service;
  final MessagePopupServerDetails serverDetails;
  final DetailsMenuAction action;
  final void Function({bool returnVal}) popDetails;
  final void Function(String title, String body, {SnackbarType type}) showSnack;
  final Chat? dmChat;
  final bool isEmbeddedMedia;

  const MessagePopupActionContext({
    required this.context,
    required this.widthContext,
    required this.cvController,
    required this.messageState,
    required this.message,
    required this.part,
    required this.chat,
    required this.service,
    required this.serverDetails,
    required this.action,
    required this.popDetails,
    required this.showSnack,
    required this.dmChat,
    required this.isEmbeddedMedia,
  });
}
