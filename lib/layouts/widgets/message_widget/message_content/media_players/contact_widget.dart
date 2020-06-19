import 'dart:io';

import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class ContactWidget extends StatefulWidget {
  ContactWidget({
    Key key,
    this.file,
    this.attachment,
  }) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _ContactWidgetState createState() => _ContactWidgetState();
}

class _ContactWidgetState extends State<ContactWidget> {
  Contact contact;
  var initials;

  @override
  void initState() {
    super.initState();

    String appleContact = widget.file.readAsStringSync();
    contact = AttachmentHelper.parseAppleContact(appleContact);
    initials = getInitials(contact.displayName, " ");
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 60,
        width: 250,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              MethodChannelInterface().invokeMethod("CreateContact", {
                "path": "/attachments/" +
                    widget.attachment.guid +
                    "/" +
                    basename(widget.file.path)
              });
            },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(
                    contact.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(
                    flex: 1,
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        colors: [HexColor('a0a4af'), HexColor('848894')],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Container(
                      child: (initials is Icon)
                          ? initials
                          : Text(
                              initials,
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                      alignment: AlignmentDirectional.center,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
