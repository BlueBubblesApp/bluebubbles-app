import 'dart:convert';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class ContactCard extends StatefulWidget {
  ContactCard({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);
  final PlatformFile file;
  final Attachment attachment;

  @override
  State<ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends OptimizedState<ContactCard> with AutomaticKeepAliveClientMixin {
  Contact? contact;

  @override
  void initState() {
    super.initState();
    updateObx(() {
      init();
    });
  }

  void init() async {
    late String appleContact;

    if (kIsWeb || widget.file.path == null) {
      appleContact = utf8.decode(widget.file.bytes!);
    } else {
      appleContact = await File(widget.file.path!).readAsString();
    }

    final lines = appleContact.split("\n");
    final indices = <int>[];
    final avatarLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith(" ")) {
        indices.add(i);
      }
    }

    if (indices.isNotEmpty) {
      avatarLines.add(lines[indices.first - 1].trim());
    }

    for (int i in indices) {
      avatarLines.add(lines[i].trim());
    }

    if (indices.isNotEmpty) {
      lines.removeRange(indices.first - 1, indices.last + 1);
    }

    final avatarStr = avatarLines.join();

    try {
      contact = as.parseAppleContact(appleContact);
    } catch (ex) {
      contact = Contact(displayName: "Invalid Contact", id: randomString(8));
    }

    if (contact != null) {
      final map = contact!.toMap();
      if (avatarStr.isNotEmpty) {
        map["avatar"] = "/${avatarStr.split("/").sublist(1).join('/').trim()}";
      }
      contact = Contact.fromMap(map);
    }

    if (!kIsWeb && widget.file.path != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox(
      height: 60,
      width: 250,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (kIsWeb || widget.file.path == null) {
              final content = base64.encode(widget.file.bytes!);
              html.AnchorElement(
                  href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                ..setAttribute("download", widget.file.name)
                ..click();
            } else {
              mcs.invokeMethod(
                "open_file",
                {
                  "path": "/attachments/${widget.attachment.guid!}/${basename(widget.file.path!)}",
                  "mimeType": "text/x-vcard",
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child:  Text(
                    contact?.displayName ?? 'Unknown',
                    style: context.theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
                const SizedBox(width: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ContactAvatarWidget(
                      handle: null,
                      contact: contact,
                      borderThickness: 0.5,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 5.0),
                      child: Icon(
                        iOS ? CupertinoIcons.forward : Icons.arrow_forward,
                        color: context.theme.colorScheme.outline,
                        size: 15,
                      ),
                    )
                  ],
                )
              ],
            )
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
