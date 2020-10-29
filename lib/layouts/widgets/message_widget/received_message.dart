import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/widget_helper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final double offset;
  final bool showTail;
  final Message message;
  final Message olderMessage;
  // final OverlayEntry overlayEntry;
  final Map<String, String> timeStamp;
  final bool showHandle;
  final List<Widget> customContent;
  final bool isFromMe;
  final Widget attachments;
  final SavedAttachmentData savedAttachmentData;
  final bool isGroup;

  // Sub-widgets
  final stickersWidget;
  final attachmentsWidget;
  final reactionsWidget;
  final urlPreviewWidget;

  ReceivedMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.message,
    // @required this.overlayEntry,
    @required this.timeStamp,
    @required this.showHandle,
    @required this.customContent,
    @required this.isFromMe,
    @required this.attachments,
    @required this.savedAttachmentData,
    @required this.isGroup,

    // Sub-widgets
    @required this.stickersWidget,
    @required this.attachmentsWidget,
    @required this.reactionsWidget,
    @required this.urlPreviewWidget,
    this.offset,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage> {
  String contactTitle = "";
  MemoryImage contactImage;
  Contact contact;
  bool hasHyperlinks = false;

  @override
  initState() {
    super.initState();
    getContactTitle();

     this.hasHyperlinks = parseLinks(widget.message.text).isNotEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    getContactTitle();
    getContact();
    fetchAvatar();

    ContactManager().stream.listen((List<String> addresses) {
      // Check if any of the addresses are members of the chat
      if (!addresses.contains(widget.message.handle.address)) return;
      fetchAvatar();
    });
  }

  void fetchAvatar() async {
    MemoryImage avatar = await loadAvatar(null, widget.message.handle.address);
    if (contactImage == null ||
        contactImage.bytes.length != avatar.bytes.length) {
      contactImage = avatar;
      if (this.mounted) setState(() {});
    }
  }

  void getContact() {
    ContactManager()
        .getCachedContact(widget.message.handle.address)
        .then((Contact contact) {
      if (contact != null) {
        if (this.contact == null ||
            this.contact.identifier != contact.identifier) {
          this.contact = contact;
          if (this.mounted) setState(() {});
        }
      }
    });
  }

  void getContactTitle() {
    if (widget.message.handle == null || !widget.showHandle) return;

    ContactManager()
        .getContactTitle(widget.message.handle.address)
        .then((String title) {
      if (title != contactTitle) {
        contactTitle = title;
        if (this.mounted) setState(() {});
      }
    });
  }

  /// Builds the message bubble with teh tail (if applicable)
  Widget _buildMessageWithTail() {
    List<Widget> msgStack = [
      Container(
        margin: EdgeInsets.only(
            top: widget.message.hasReactions ? 12 : 0, left: 10, right: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 3 / 4,
        ),
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 14,
        ),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).accentColor),
        child: RichText(
          text: TextSpan(
            children: WidgetHelper.buildMessageSpans(context, widget.message),
            style: Theme.of(context).textTheme.bodyText1,
          )
        )
      ),
    ];

    if (widget.showTail) {
      msgStack.insert(
          0, MessageTail(isFromMe: false));
    }

    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: msgStack
    );
  }

  /// Adds reacts to a [message] widget
  Widget _addReactionsToWidget(Widget message) {
    return Stack(
      alignment: AlignmentDirectional.topEnd,
      children: [
        message,
        widget.reactionsWidget
      ],
    );
  }

  /// Adds reacts to a [message] widget
  Widget _addStickersToWidget(Widget message) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        message,
        widget.stickersWidget
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message == null) return Container();

    dynamic initials = getInitials(contact?.displayName ?? "", " ", size: 25);

    // The column that holds all the "messages"
    List<Widget> messageColumn = [];

    // First, add the message sender (if applicable)
    if (!sameSender(widget.message, widget.olderMessage) ||
        !widget.message.dateCreated
            .isWithin(widget.olderMessage.dateCreated, minutes: 30)) {
      messageColumn.add(
        Padding(
          padding: EdgeInsets.only(left: 25.0, top: 5.0, bottom: 3.0),
          child: Text(
            contactTitle,
            style: Theme.of(context).textTheme.subtitle1,
          ),
        )
      );
    }

    // Second, add the attachments
    if (isEmptyString(widget.message.text)) {
      messageColumn.add(_addStickersToWidget(_addReactionsToWidget(widget.attachmentsWidget)));
    } else {
      messageColumn.add(widget.attachmentsWidget);
    }

    // Third, let's add the message or URL preview
    Widget message;
    if (widget.message.hasDdResults && this.hasHyperlinks) {
      message = Padding(padding: EdgeInsets.only(left: 10.0), child: widget.urlPreviewWidget);
    } else if (!isEmptyString(widget.message.text)) {
      message = _buildMessageWithTail();
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      messageColumn.add(_addStickersToWidget(_addReactionsToWidget(message)));
    }

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [];
    if (widget.showTail && widget.isGroup) {
      msgRow.add(Padding(
          padding: EdgeInsets.only(
              left: 5.0,
          ),
          child: ContactAvatarWidget(
              contactImage: contactImage,
              initials: initials,
              size: 30,
              fontSize: 14)));
    }

    // Add the message column to the row
    msgRow.add(Padding(
      // Padding to shift the bubble up a bit, relative to the avatar
      padding: EdgeInsets.only(
        bottom: (widget.showTail)
          ? 5.0
          : 3.0
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messageColumn,
      )
    ));

    // Finally, create a container row so we can have the swipe timestamp
    return Padding(
      // Add padding when we are showing the avatar
      padding: EdgeInsets.only(
        left: (!widget.showTail && widget.isGroup)
          ? 35.0
          : 0.0
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: msgRow
          ),
          WidgetHelper.buildMessageTimestamp(
            context, widget.message, widget.offset)
        ],
      )
    );

    // return Column(
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: <Widget>[
    //     contactItem,
    //     Row(
    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //       children: <Widget>[
    //         Row(
    //           mainAxisAlignment: MainAxisAlignment.start,
    //           crossAxisAlignment: CrossAxisAlignment.end,
    //           children: msgItems,
    //         ),
    //         WidgetHelper.buildMessageTimestamp(
    //             context, widget.message, widget.offset)
    //       ],
    //     ),
    //     widget.timeStamp != null
    //         ? Padding(
    //             padding: const EdgeInsets.all(14.0),
    //             child: Row(
    //               mainAxisAlignment: MainAxisAlignment.center,
    //               children: <Widget>[
    //                 RichText(
    //                   text: TextSpan(
    //                     style: Theme.of(context).textTheme.subtitle2,
    //                     children: [
    //                       TextSpan(
    //                         text: "${widget.timeStamp["date"]}, ",
    //                         style: Theme.of(context)
    //                             .textTheme
    //                             .subtitle2
    //                             .apply(fontWeightDelta: 10),
    //                       ),
    //                       TextSpan(text: "${widget.timeStamp["time"]}")
    //                     ],
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           )
    //         : Container()
    //   ],
    // );
  }
}
