import 'package:bluebubbles/app/widgets/components/reaction.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

class ReactionsWidget extends StatefulWidget {
  ReactionsWidget({
    Key? key,
    required this.associatedMessages,
    this.bigPin = false,
    this.size = 28,
  }) : super(key: key);
  final List<Message> associatedMessages;
  final bool bigPin;
  final double size;

  @override
  State<ReactionsWidget> createState() => _ReactionsWidgetState();
}

class _ReactionsWidgetState extends State<ReactionsWidget> {
  @override
  Widget build(BuildContext context) {
    Map<String, Reaction> reactionsMap = {};
    // Filter associated messages down to just the sticker
    List<Message> reactions =
        widget.associatedMessages.where((item) => ReactionTypes.toList().contains(item.associatedMessageType?.replaceAll("-", ""))).toList();


    final bool hideReactions =
        ss.settings.redactedMode.value && ss.settings.hideReactions.value;

    // If the reactions are empty, return nothing
    if (reactions.isEmpty || hideReactions || Reaction.getUniqueReactionMessages(reactions).isEmpty) {
      return Container();
    }

    // Filter down the reactions by the newest for each user
    reactionsMap = Reaction.getLatestReactionMap(reactions);

    // Build the widget list from the map
    List<Widget> reactionWidgets = [];
    int tmpIdx = 0;
    reactionsMap.forEach((String reactionType, Reaction item) {
      Widget? itemWidget = item.getSmallWidget(
        context,
        bigPin: widget.bigPin,
        size: widget.size,
      );
      if (itemWidget != null) {
        reactionWidgets.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              tmpIdx.toDouble() * 15.0,
              1.0,
              0,
              0,
            ),
            child: itemWidget,
          ),
        );
        tmpIdx++;
      }
    });

    // This is a workaround for a flutter bug
    if (reactionWidgets.length == 1) {
      reactionWidgets.add(Text(''));
    }

    // Build the actual reaction bubbles
    return AnimatedSize(
      duration: Duration(milliseconds: 200),
      reverseDuration: Duration(milliseconds: 200),
      curve: Curves.bounceInOut,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.passthrough,
        alignment: Alignment.bottomLeft,
        children: reactionWidgets,
      ),
    );
  }
}
