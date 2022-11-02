import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum ItemTypes {
  participantAdded,
  participantRemoved,
  nameChanged,
  participantLeft,
}

class GroupEvent extends StatelessWidget {
  GroupEvent({
    Key? key,
    required this.message,
  }) : super(key: key) {
    text = MessageHelper.getGroupEventText(message!);
  }

  final Message? message;
  late final String text;

  @override
  Widget build(BuildContext context) {
    List<Widget> extras = [];
    // if (text == 'Unknown group event') {
    //   extras.addAll([
    //     Text(
    //       "ACTUAL TEXT: '${widget.message.fullText}'",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "IS EMPTY: ${isNullOrEmptyString(widget.message.fullText)}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "IS EMPTY (WITH STRIP): ${isNullOrEmptyString(widget.message.fullText, stripWhitespace: true)}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "BALLOON BUNDLE ID: ${widget.message.balloonBundleId ?? "NULL"}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "HAS ATTACHMENTS: ${widget.message.hasAttachments}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "ATTACHMENTS LENGTH: ${widget.message.attachments.length}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "HAS DD RESULTS: ${widget.message.hasDdResults}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "METADATA: ${widget.message.metadata.toString()}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "SUBJECT: ${widget.message.subject}",
    //       style: Theme.of(context).textTheme.labelMedium.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //   ]);
    // }

    return Flex(direction: Axis.horizontal, children: [
      Flexible(
        fit: FlexFit.tight,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                ...extras
              ],
            )),
      ),
    ]);
  }
}