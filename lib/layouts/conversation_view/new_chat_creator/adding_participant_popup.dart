import 'dart:async';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class AddingParticipantPopup extends StatefulWidget {
  final List<UniqueContact> contacts;
  final Chat chat;

  AddingParticipantPopup({Key? key, required this.contacts, required this.chat}) : super(key: key);

  @override
  _AddingParticipantPopupState createState() => _AddingParticipantPopupState();
}

class _AddingParticipantPopupState extends State<AddingParticipantPopup> {
  int index = 0;
  late String title;

  @override
  void initState() {
    super.initState();
    recursiveAddParticipants(0);
  }

  void recursiveAddParticipants(int i) {
    index = i;
    title = "Adding participant ${widget.contacts[i].displayName}";
    if (mounted) setState(() {});

    Map<String, dynamic> params = {};
    params["identifier"] = widget.chat.guid;
    params["address"] = cleansePhoneNumber(widget.contacts[i].address!);
    SocketManager().sendMessage("add-participant", params, (data) {
      if (data['status'] != 200) {
        if (mounted) {
          setState(() {
            title = "Failed to add participant ${widget.contacts[i].displayName}";
          });
        }
        Timer(Duration(seconds: 3), () {
          if (i < widget.contacts.length - 1) {
            recursiveAddParticipants(i + 1);
          } else {
            if (mounted) {
              Navigator.pop(context);
            }
          }
        });
      } else {
        Chat chat = Chat.fromMap(data["data"]);
        chat.save();
        if (i < widget.contacts.length - 1) {
          recursiveAddParticipants(i + 1);
        } else {
          if (mounted) {
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
      backgroundColor: Theme.of(context).accentColor,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyText1,
      ),
      content: Container(
        height: 5,
        child: Center(
          child: LinearProgressIndicator(
            backgroundColor: Colors.grey,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            value: (index) / widget.contacts.length,
          ),
        ),
      ),
    );
  }
}
