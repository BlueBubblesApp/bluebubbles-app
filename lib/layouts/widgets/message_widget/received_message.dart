import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/widget_helper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final double offset;
  // final OverlayEntry overlayEntry;
  final Map<String, String> timeStamp;
  final bool showHandle;
  final List<Widget> customContent;
  final bool isFromMe;
  final Widget attachments;
  final SavedAttachmentData savedAttachmentData;

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

  @override
  Widget build(BuildContext context) {
    var initials = getInitials(contact?.displayName ?? "", " ", size: 25);

    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: Theme.of(context).accentColor,
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
        ),
      ),
      Container(
        margin: EdgeInsets.only(bottom: 2),
        height: 28,
        width: 11,
        decoration: BoxDecoration(
            color: Theme.of(context).backgroundColor,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(8))),
      ),
    ];

    List<Widget> stack = <Widget>[
      Container(
        height: 30,
        width: 6,
        color: Theme.of(context).backgroundColor,
      )
    ];
    if (widget.showTail) {
      stack.insertAll(0, tail);
    }

    List<Widget> messageWidget = [
      widget.message != null && !isEmptyString(widget.message.text)
          ? Stack(
              alignment: AlignmentDirectional.bottomStart,
              children: <Widget>[
                Stack(
                  alignment: AlignmentDirectional.bottomStart,
                  children: stack,
                ),
                Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 3 / 4.5,
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
                    ))),
              ],
            )
          : Container()
    ];

    Widget contactItem = new Container(width: 0, height: 0);
    if (!sameSender(widget.message, widget.olderMessage) ||
        !widget.message.dateCreated
            .isWithin(widget.olderMessage.dateCreated, minutes: 30)) {
      contactItem = Padding(
        padding: EdgeInsets.only(left: 50.0, top: 5.0, bottom: 3.0),
        child: Text(
          contactTitle,
          style: Theme.of(context).textTheme.subtitle1,
        ),
      );
    }

    List<Widget> msgItems = [];
    if (widget.showTail && widget.showHandle) {
      msgItems.add(Padding(
          padding: EdgeInsets.only(
              left: 5.0,
              bottom: (isEmptyString(sanitizeString(widget.message.text)))
                  ? 5.0
                  : 10.0),
          child: ContactAvatarWidget(
              contactImage: contactImage,
              initials: initials,
              size: 30,
              fontSize: 14)));
    }

    List<Widget> messageCol = [];
    if (widget.attachments != null)
      messageCol.add(Padding(padding: EdgeInsets.only(bottom: 1.0), child: widget.attachments));

    List<Attachment> previewAttachments = [];
    if (widget.message.hasDdResults) {
      for (Attachment i in widget.savedAttachmentData?.attachments ?? []) {
        if (i.mimeType == null) {
          previewAttachments.add(i);
        }
      }
    }

    if (previewAttachments.length > 0) {
      messageCol.add(Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: 3.0,
            ),
            child: UrlPreviewWidget(
              linkPreviews: previewAttachments,
              message: widget.message,
              savedAttachmentData: widget.savedAttachmentData,
            )
          )
        ]
      ));
    } else {
      messageCol.add(Padding(
        padding: EdgeInsets.only(
            bottom: widget.showTail ? 10.0 : 3.0,
            left: widget.showTail || !widget.showHandle ? 0.0 : 35.0),
        child: Stack(
          alignment: Alignment.topRight,
          children: <Widget>[
            AnimatedPadding(
              duration: Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(
                right: widget.message != null &&
                        widget.message.hasReactions &&
                        !widget.message.hasAttachments
                    ? 6.0
                    : 0.0,
                top: widget.message != null &&
                        widget.message.hasReactions &&
                        !widget.message.hasAttachments
                    ? 14.0
                    : 0.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: messageWidget,
              ),
            ),
            !widget.message.hasAttachments
                ? ReactionsWidget(
                    message: widget.message,
                  )
                : Container(),
          ],
        ),
      ));
    }
    
    msgItems.addAll(messageCol);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        contactItem,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: msgItems,
            ),
            WidgetHelper.buildMessageTimestamp(context, widget.message, widget.offset)
          ],
        ),
        widget.timeStamp != null
            ? Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.subtitle2,
                        children: [
                          TextSpan(
                            text: "${widget.timeStamp["date"]}, ",
                            style: Theme.of(context)
                                .textTheme
                                .subtitle2
                                .apply(fontWeightDelta: 10),
                          ),
                          TextSpan(text: "${widget.timeStamp["time"]}")
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Container()
      ],
    );
  }
}
