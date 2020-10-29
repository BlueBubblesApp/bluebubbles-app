// import 'package:bluebubbles/helpers/utils.dart';
// import 'package:bluebubbles/managers/contact_manager.dart';
// import 'package:bluebubbles/repository/models/handle.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:flutter/material.dart';

// class ContactAvatarGroupWidget extends StatefulWidget {
//   ContactAvatarGroupWidget({Key key, this.participants}) : super(key: key);
//   final List<Handle> participants;

//   @override
//   _ContactAvatarGroupWidgetState createState() =>
//       _ContactAvatarGroupWidgetState();
// }

// class _ContactAvatarGroupWidgetState extends State<ContactAvatarGroupWidget> {
//   List<dynamic> icons;

//   @override
//   void initState() {
//     super.initState();
//     participants = widget.participants.sublist(0, 2);

//     ContactManager()
//         .getCachedContact(widget.chat.participants[0].address)
//         .then((Contact c) {
//       if (c == null && this.mounted) {
//         initials = Icon(Icons.person, color: Colors.white, size: 30);
//         setState(() {});
//       } else {
//         loadAvatar(widget.chat, widget.chat.participants[0].address)
//             .then((MemoryImage image) {
//           setContactImage(image);
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return;
//   }
// }
