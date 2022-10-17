import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/redacted_helper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class ReactionDetailWidget extends StatefulWidget {
  ReactionDetailWidget({
    Key? key,
    required this.handle,
    required this.message,
  }) : super(key: key);
  final Handle? handle;
  final Message message;

  @override
  State<ReactionDetailWidget> createState() => _ReactionDetailWidgetState();
}

class _ReactionDetailWidgetState extends State<ReactionDetailWidget> {
  String? contactTitle;

  @override
  void initState() {
    super.initState();

    contactTitle = widget.message.isFromMe! ? "You" : widget.handle!.address;

    String? title = widget.handle?.displayName;
    if (title != contactTitle) {
      contactTitle = title;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hide = ss.settings.redactedMode.value && ss.settings.hideReactions.value;
    if (hide) return Container();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
          child: ContactAvatarWidget(
            handle: widget.message.isFromMe! ? null : widget.handle,
            borderThickness: 0.1,
            editable: false,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            widget.message.isFromMe! ? "You" : getContactName(context, contactTitle, widget.handle?.address),
            style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
          ),
        ),
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: widget.message.isFromMe! ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
            boxShadow: [
              BoxShadow(
                blurRadius: 1.0,
                color: context.theme.colorScheme.outline,
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 7.0, right: 7.0, bottom: 7.0),
            child: SvgPicture.asset(
              'assets/reactions/${widget.message.associatedMessageType}-black.svg',
              color: widget.message.associatedMessageType == "love" ? Colors.pink : widget.message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface,
            ),
          ),
        )
      ],
    );
  }
}
