import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/search/search_text_box.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachment.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  SearchView({Key key}) : super(key: key);

  @override
  _SearchViewState createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  List<Attachment> recentAttachments = [];
  List<Handle> recentContacts = [];

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    recentAttachments = await Attachment.find();
    ChatBloc().chats.sublist(0, 20).forEach((chat) {
      if (recentContacts.length >= 20) return;
      chat.participants.forEach((participant) {
        if (recentContacts.length >= 20) return;
        if (recentContacts
                .where((element) => element.address == participant.address)
                .length ==
            0) {
          recentContacts.add(participant);
        }
      });
    });
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      body: CustomScrollView(
        physics: ThemeSwitcher.getScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(top: 60),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: SearchTextBox(
                autoFocus: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 100,
              child: ListView.builder(
                physics: ThemeSwitcher.getScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  if (index >= recentContacts.length) return Container();
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Center(
                      child: ContactAvatarWidget(
                        size: 43,
                        handle: recentContacts[index],
                      ),
                    ),
                  );
                },
                itemCount: 20,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  child: Text("Test"),
                );
              },
            ),
          ),
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container();
              },
              childCount: 6,
            ),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          ),
        ],
      ),
    );
  }
}
