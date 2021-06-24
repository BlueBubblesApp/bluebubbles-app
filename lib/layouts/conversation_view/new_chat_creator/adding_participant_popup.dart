import 'dart:async';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class AddingParticipantPopup extends StatefulWidget {
  final List<UniqueContact> contacts;
  final Chat chat;

  AddingParticipantPopup({Key key, @required this.contacts, this.chat}) : super(key: key);

  @override
  _AddingParticipantPopupState createState() => _AddingParticipantPopupState();
}

class _AddingParticipantPopupState extends State<AddingParticipantPopup> {
  int index = 0;
  String title;

  @override
  void initState() {
    super.initState();
    recursiveAddParticipants(0);
  }

  void recursiveAddParticipants(int i) {
    index = i;
    title = "Adding participant ${widget.contacts[i].displayName}";
    if (this.mounted) setState(() {});

    Map<String, dynamic> params = {};
    params["identifier"] = widget.chat.guid;
    params["address"] = cleansePhoneNumber(widget.contacts[i].address);
    SocketManager().sendMessage("add-participant", params, (data) async {
      if (data['status'] != 200) {
        if (this.mounted)
          setState(() {
            title = "Failed to add participant ${widget.contacts[i].displayName}";
          });
        Timer(Duration(seconds: 3), () {
          if (i < widget.contacts.length - 1) {
            recursiveAddParticipants(i + 1);
          } else {
            if (this.mounted) {
              Navigator.pop(context);
            }
          }
        });
      } else {
        Chat chat = Chat.fromMap(data["data"]);
        await chat.save();
        if (i < widget.contacts.length - 1) {
          recursiveAddParticipants(i + 1);
        } else {
          if (this.mounted) {
            setState(() {
              title = "Finished";
              index = widget.contacts.length;
            });
            Navigator.pop(context);
            Navigator.pop(context);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Get.theme.accentColor,
      title: Text(
        title,
        style: Get.theme.textTheme.bodyText1,
      ),
      content: Container(
        height: 5,
        child: Center(
          child: LinearProgressIndicator(
            backgroundColor: Colors.grey,
            valueColor: AlwaysStoppedAnimation<Color>(Get.theme.primaryColor),
            value: (index) / widget.contacts.length,
          ),
        ),
      ),
    );
  }
}
