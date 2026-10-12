import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_action_context.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

void openLink(MessagePopupActionContext ctx) {
  final String? url = ctx.part.url;
  MethodChannelSvc.actions.openBrowser(link: (url ?? ctx.part.text) ?? '');
  ctx.popDetails();
}

void copyText(MessagePopupActionContext ctx) {
  Clipboard.setData(ClipboardData(text: ctx.part.fullText));
  ctx.popDetails();
  showCopiedToast("Copied to clipboard");
}

void copySelection(MessagePopupActionContext ctx) {
  showCopySelectionDialog(ctx.context, ctx.part.fullText);
}

/// Shows [text] in a dialog where any part of it can be selected and copied.
void showCopySelectionDialog(BuildContext context, String text) {
  showBBDialog(
    context: context,
    title: "Copy Selection",
    content: SelectableText(text, style: Theme.of(context).extension<BubbleText>()!.bubbleText),
  );
}
