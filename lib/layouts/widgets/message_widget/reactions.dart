import 'package:bluebubble_messages/repository/models/message.dart';
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
  Map<String, List<Message>> reactions = new Map();
  final String like = "like";
  final String love = "love";
  final String dislike = "dislike";
  final String question = "question";
  final String emphasize = "emphasize";
  final String laugh = "laugh";

  @override
  void initState() {
    super.initState();
    if (widget.message != null && widget.message.hasReactions)
      reactionRetreivalFuture = widget.message.getReactions();
  }

  @override
  Widget build(BuildContext context) {
    return reactionRetreivalFuture != null
        ? FutureBuilder(
            future: reactionRetreivalFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data.length == 0) {
                return Container();
              }
              reactions[like] = [];
              reactions[love] = [];
              reactions[dislike] = [];
              reactions[question] = [];
              reactions[emphasize] = [];
              reactions[laugh] = [];

              snapshot.data.forEach((reaction) {
                reactions[reaction.associatedMessageType].add(reaction);
              });
              reactions.values.forEach((element) {
                element.sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
              });
              debugPrint(
                  "completed future with data " + snapshot.data.toString());

              Map<Widget, Message> reactionIcon = new Map();
              reactions.keys.forEach(
                (String key) {
                  if (reactions[key].length != 0) {
                    reactionIcon[Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SvgPicture.asset(
                        'assets/reactions/$key-black.svg',
                        color: key == love ? Colors.pink : Colors.white,
                      ),
                    )] = reactions[key].last;
                  }
                },
              );
              return Stack(
                alignment: widget.message.isFromMe
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                children: <Widget>[
                  for (int i = 0; i < reactionIcon.keys.toList().length; i++)
                    Padding(
                      padding:
                          EdgeInsets.fromLTRB(i.toDouble() * 20.0, 0, 0, 0),
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: reactionIcon[reactionIcon.keys.toList()[i]]
                                  .isFromMe
                              ? Colors.blue
                              : Theme.of(context).accentColor,
                          boxShadow: [
                            new BoxShadow(
                              blurRadius: 5.0,
                              offset: Offset(
                                  3.0 * (widget.message.isFromMe ? 1 : -1),
                                  0.0),
                              color: Colors.black,
                            )
                          ],
                        ),
                        child: reactionIcon.keys.toList()[i],
                      ),
                    ),
                ],
              );
            },
          )
        : Container();
  }
}
