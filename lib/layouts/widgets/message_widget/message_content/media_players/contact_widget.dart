import 'dart:convert';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class ContactWidget extends StatefulWidget {
  ContactWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);
  final PlatformFile file;
  final Attachment attachment;

  @override
  _ContactWidgetState createState() => _ContactWidgetState();
}

class _ContactWidgetState extends State<ContactWidget> {
  Contact? contact;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    String appleContact;

    if (kIsWeb || widget.file.path == null) {
      appleContact = utf8.decode(widget.file.bytes!);
    } else {
      appleContact = await File(widget.file.path!).readAsString();
    }

    try {
      contact = AttachmentHelper.parseAppleContact(appleContact);
    } catch (ex) {
      contact = Contact(displayName: "Invalid Contact", id: randomString(8));
    }

    if (!kIsWeb && widget.file.path != null && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String? initials = contact == null ? null : getInitials(contact!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 60,
        width: 250,
        child: Material(
          color: Theme.of(context).colorScheme.secondary,
          child: InkWell(
            onTap: () async {
              if (kIsWeb || widget.file.path == null) {
                final content = base64.encode(widget.file.bytes!);
                html.AnchorElement(
                    href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                  ..setAttribute("download", widget.file.name)
                  ..click();
              } else {
                MethodChannelInterface().invokeMethod(
                  "open_file",
                  {
                    "path": "/attachments/" +
                        widget.attachment.guid! +
                        "/" +
                        basename(widget.file.path!),
                    "mimeType": "text/x-vcard",
                  },
                );
              }
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
                            style: Theme.of(context).textTheme.subtitle2,
                          ),
                          Text(
                            (contact?.displayName ?? '').isEmpty ? 'Unknown' : contact!.displayName,
                            style: Theme.of(context).textTheme.bodyText1,
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
                          child: initials == null
                            ? Icon(
                                SettingsManager().settings.skin.value == Skins.iOS
                                    ? CupertinoIcons.person_fill
                                    : Icons.person,
                                color: Theme.of(context).textTheme.headline1?.color!)
                            : Text(
                                initials,
                                style: Theme.of(context).textTheme.headline1,
                            ),
                          alignment: AlignmentDirectional.center,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 5.0),
                        child: Icon(
                          SettingsManager().settings.skin.value == Skins.iOS
                              ? CupertinoIcons.forward
                              : Icons.arrow_forward,
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
