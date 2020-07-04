// import 'dart:io';

// import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
// import 'package:bluebubble_messages/helpers/utils.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_file.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/loaction_widget.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
// import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
// import 'package:bluebubble_messages/managers/settings_manager.dart';
// import 'package:bluebubble_messages/repository/models/attachment.dart';
// import 'package:bluebubble_messages/repository/models/message.dart';
// import 'package:bluebubble_messages/socket_manager.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:link_previewer/link_previewer.dart';
// import 'package:mime/mime.dart';
// import 'package:mime_type/mime_type.dart';
// import 'package:path/path.dart';

// class MessageContent extends StatefulWidget {
//   MessageContent({
//     Key key,
//     this.customContent,
//     this.message,
//     this.isFromMe,
//   }) : super(key: key);
//   final List<Widget> customContent;
//   final Message message;
//   final bool isFromMe;

//   @override
//   _MessageContentState createState() => _MessageContentState();
// }

// class _MessageContentState extends State<MessageContent> {
//   List<Attachment> attachments = <Attachment>[];
//   List chatAttachments = [];
//   bool _hasLinks = false;
//   List<Widget> _content = <Widget>[];

//   @override
//   void initState() {
//     super.initState();
//     getAttachments();
//   }

//   void getAttachments() {
//     if (widget.customContent != null) return;
//     chatAttachments = [];
//     Message.getAttachments(widget.message).then((value) {
//       attachments = [];
//     });
//   }

//   List<Widget> _buildContent(BuildContext context) {
//     if (widget.customContent != null) {
//       _content = widget.customContent;
//       return widget.customContent;
//     }

//     if (_hasLinks) {
//       String link = widget.message.text;
//       if (!Uri.parse(widget.message.text).isAbsolute) {
//         link = "https://" + widget.message.text;
//       }
//       attachmentWidget.add(
//         LinkPreviewer(
//           link: link,
//         ),
//       );
//     } else if (!isEmptyString(widget.message.text) && attachments.length > 0) {
//       attachmentWidget.add(
//         Padding(
//           padding: EdgeInsets.only(left: 20, right: 10),
//           child: Text(
//             widget.message.text,
//             style: widget.isFromMe
//                 ? Theme.of(context).textTheme.bodyText2
//                 : Theme.of(context).textTheme.bodyText1,
//           ),
//         ),
//       );
//     } else if (!isEmptyString(widget.message.text) && attachments.length == 0) {
//       attachmentWidget.add(
//         Text(
//           widget.message.text,
//           style: widget.isFromMe
//               ? Theme.of(context).textTheme.bodyText2
//               : Theme.of(context).textTheme.bodyText1,
//         ),
//       );
//     }

//     // Add spacing to items in a message
//     List<Widget> output = [];
//     for (int i = 0; i < attachmentWidget.length; i++) {
//       output.add(attachmentWidget[i]);
//       if (i != attachmentWidget.length - 1) {
//         output.add(Container(height: 8.0));
//       }
//     }
//     _content = output;

//     return output;
//   }

//   @override
//   Widget build(BuildContext context) {
//     _buildContent(context);

//     double bottomPadding =
//         widget.message != null && isEmptyString(widget.message.text) ? 0 : 8;
//     double sidePadding = widget.message != null &&
//             !isEmptyString(widget.message.text) &&
//             _content.length > 0 &&
//             _content[0] is Text
//         ? 14
//         : 0;
//     double topPadding = widget.message != null &&
//             !isEmptyString(widget.message.text) &&
//             _content.length > 0 &&
//             _content[0] is Text
//         ? 8
//         : 0;
//     return;
//   }
// }
