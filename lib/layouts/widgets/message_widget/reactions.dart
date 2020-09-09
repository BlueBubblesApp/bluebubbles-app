import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Reactions extends StatefulWidget {
  Reactions({
    Key key,
    @required this.message,
  }) : super(key: key);
  final Message message;

  @override
  _ReactionsState createState() => _ReactionsState();
}

class _ReactionsState extends State<Reactions> {
  Future<List<Message>> reactionRetreivalFuture;
  Map<String, Reaction> reactions = new Map();

  @override
  Widget build(BuildContext context) {
    if (widget.message != null && widget.message.hasReactions)
      reactionRetreivalFuture = widget.message.getReactions();

    return reactionRetreivalFuture != null
        ? FutureBuilder(
            future: reactionRetreivalFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data.length == 0) {
                return Container();
              }
              
              reactions = Reaction.getLatestReactionMap(snapshot.data);

              double topPadding = 1.0;
              double rightPadding = 0;
              if (widget.message.hasAttachments) {
                topPadding = 10.0;
                rightPadding = 5.0;
              }
              
              List<Widget> reactionWidgets = [];
              int tmpIdx = 0;
              reactions.forEach((String reactionType, Reaction item) {
                Widget itemWidget = item.getSmallWidget(context);
                if (itemWidget != null) {
                  reactionWidgets.add(Padding(
                    padding:
                        EdgeInsets.fromLTRB(tmpIdx.toDouble() * 10.0, topPadding, rightPadding, 0),
                    child: itemWidget,
                  ));
                  tmpIdx++;
                }
              });

              // This is a workaround for a flutter bug
              reactionWidgets.add(Text(''));

              return Stack(
                clipBehavior: Clip.hardEdge,
                overflow: Overflow.clip,
                fit: StackFit.passthrough,
                alignment: Alignment.bottomLeft,
                children: reactionWidgets,
              );
            },
          )
        : Container();
  }
}
