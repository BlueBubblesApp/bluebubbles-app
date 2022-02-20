import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/attachment_list_item.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:flutter/material.dart';

class TextFieldAttachmentList extends StatefulWidget {
  TextFieldAttachmentList({Key? key, required this.attachments, required this.onRemove}) : super(key: key);
  final List<PlatformFile> attachments;
  final Function(PlatformFile) onRemove;

  @override
  _TextFieldAttachmentListState createState() => _TextFieldAttachmentListState();
}

class _TextFieldAttachmentListState extends State<TextFieldAttachmentList> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: AnimatedSize(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.attachments.isNotEmpty ? 100 : 0,
          ),
          child: GridView.builder(
            itemCount: widget.attachments.length,
            scrollDirection: Axis.horizontal,
            physics: ThemeSwitcher.getScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
            ),
            itemBuilder: (context, int index) {
              return AttachmentListItem(
                key: Key("attachmentList" + widget.attachments[index].name),
                file: widget.attachments[index],
                onRemove: () {
                  widget.onRemove(widget.attachments[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
