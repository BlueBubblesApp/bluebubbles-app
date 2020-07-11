import 'dart:ui';

import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:sprung/sprung.dart';

class MessageDetailsPopup extends StatefulWidget {
  MessageDetailsPopup({
    Key key,
    this.entry,
    this.reactions,
  }) : super(key: key);
  final OverlayEntry entry;
  final List<Message> reactions;

  @override
  _MessageDetailsPopupState createState() => _MessageDetailsPopupState();
}

class _MessageDetailsPopupState extends State<MessageDetailsPopup>
    with SingleTickerProviderStateMixin {
  List<Widget> reactionWidgets = <Widget>[];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    for (Message reaction in widget.reactions) {
      await reaction.getHandle();
      reactionWidgets.add(
        ReactionDetailWidget(
          handle: reaction.handle,
          message: reaction,
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                debugPrint("remove entry");
                widget.entry.remove();
              },
              child: Container(
                color: Colors.black.withAlpha(200),
                child: Column(
                  children: <Widget>[
                    Spacer(
                      flex: 2,
                    ),
                    AnimatedSize(
                      vsync: this,
                      duration: Duration(milliseconds: 500),
                      curve: Sprung(damped: Damped.under),
                      alignment: Alignment.center,
                      child: reactionWidgets.length > 0
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  alignment: Alignment.center,
                                  height: 120,
                                  width:
                                      MediaQuery.of(context).size.width * 9 / 5,
                                  color: Theme.of(context)
                                      .accentColor
                                      .withAlpha(100),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 30),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) {
                                        return reactionWidgets[index];
                                      },
                                      itemCount: reactionWidgets.length,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ),
                    Spacer(
                      flex: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
