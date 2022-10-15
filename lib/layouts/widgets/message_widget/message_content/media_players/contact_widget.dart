import 'dart:convert';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  State<ContactWidget> createState() => _ContactWidgetState();
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
      contact = Contact(displayName: "Invalid Contact", id: randomString(8), fakeName: "Invalid Contact");
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
          color: context.theme.colorScheme.properSurface,
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
                    "path": "/attachments/${widget.attachment.guid!}/${basename(widget.file.path!)}",
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
                            style: context.theme.textTheme.bodyMedium,
                          ),
                          Text(
                            (contact?.displayName ?? '').isEmpty ? 'Unknown' : contact!.displayName,
                            style: context.theme.textTheme.bodyMedium,
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
                                settings.settings.skin.value == Skins.iOS
                                    ? CupertinoIcons.person_fill
                                    : Icons.person,
                                color: context.theme.colorScheme.properOnSurface)
                            : Text(
                                initials,
                                style: context.theme.textTheme.titleLarge,
                            ),
                          alignment: AlignmentDirectional.center,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 5.0),
                        child: Icon(
                          settings.settings.skin.value == Skins.iOS
                              ? CupertinoIcons.forward
                              : Icons.arrow_forward,
                          color: context.theme.colorScheme.outline,
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
