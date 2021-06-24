import 'dart:io';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
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

  @override
  void initState() {
    super.initState();

    String appleContact = widget.file.readAsStringSync();

    try {
      contact = AttachmentHelper.parseAppleContact(appleContact);
    } catch (ex) {
      contact = new Contact(displayName: "Invalid Contact");
    }

    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 60,
        width: 250,
        child: Material(
          color: Get.theme.accentColor,
          child: InkWell(
            onTap: () async {
              MethodChannelInterface().invokeMethod(
                "open_file",
                {
                  "path": "/attachments/" + widget.attachment.guid + "/" + basename(widget.file.path),
                  "mimeType": "text/x-vcard",
                },
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    fit: FlexFit.loose,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Contact Card",
                            style: Get.theme.textTheme.subtitle2,
                          ),
                          Text(
                            contact?.displayName ?? "No Name",
                            style: Get.theme.textTheme.bodyText1,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            softWrap: true,
                          )
                        ]),
                  ),
                  Row(
                    children: [
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
                          child: Text(
                            contact?.initials() ?? "?",
                            style: Get.theme.textTheme.headline1,
                          ),
                          alignment: AlignmentDirectional.center,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 5.0),
                        child: Icon(
                          SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
                          color: Colors.grey,
                          size: 15,
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
