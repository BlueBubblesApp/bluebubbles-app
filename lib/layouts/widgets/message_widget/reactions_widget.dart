import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

class ReactionsWidget extends StatefulWidget {
  ReactionsWidget({
    Key key,
    @required this.message,
    @required this.associatedMessages,
  }) : super(key: key);
  final Message message;
  final List<Message> associatedMessages;

  @override
  _ReactionsWidgetState createState() => _ReactionsWidgetState();
}

class _ReactionsWidgetState extends State<ReactionsWidget> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    Map<String, Reaction> reactionsMap = new Map();
    // Filter associated messages down to just the sticker
    List<Message> reactions =
        widget.associatedMessages.where((item) => ReactionTypes.toList().contains(item.associatedMessageType)).toList();

    final bool hideReactions = SettingsManager().settings.redactedMode && SettingsManager().settings.hideReactions;

    // If the reactions are empty, return nothing
    if (reactions.isEmpty || hideReactions) {
      return Container();
    }

    // Filter down the reactions by the newest for each user
    reactionsMap = Reaction.getLatestReactionMap(reactions);

    // Build the widget list from the map
    List<Widget> reactionWidgets = [];
    int tmpIdx = 0;
    reactionsMap.forEach((String reactionType, Reaction item) {
      Widget itemWidget = item.getSmallWidget(context);
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
      vsync: this,
      curve: Curves.bounceInOut,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        overflow: Overflow.clip,
        fit: StackFit.passthrough,
        alignment: Alignment.bottomLeft,
        children: reactionWidgets,
      ),
    );
  }
}
