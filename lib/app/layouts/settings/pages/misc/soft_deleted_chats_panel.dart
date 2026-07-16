import 'package:bluebubbles/app/layouts/chat_creator/widgets/chat_creator_tile.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SoftDeletedChatsPanel extends StatefulWidget {
  const SoftDeletedChatsPanel({super.key});

  @override
  State<SoftDeletedChatsPanel> createState() => _SoftDeletedChatsPanelState();
}

class _SoftDeletedChatsPanelState extends State<SoftDeletedChatsPanel> with ThemeHelpers {
  List<Chat> _deletedChats = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadDeletedChats();
  }

  Future<void> _loadDeletedChats() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final query =
        (Database.chats.query(Chat_.dateDeleted.notNull())..order(Chat_.dateDeleted, flags: Order.descending)).build();
    final results = await runAsync(() => query.find());
    query.close();
    if (mounted) {
      setState(() {
        _deletedChats = results;
        _loaded = true;
      });
    }
  }

  Future<void> _restore(Chat chat) async {
    await ChatsSvc.unDeleteChat(chat);
    await ChatsSvc.addChat(chat);
    setState(() => _deletedChats.removeWhere((c) => c.guid == chat.guid));
    showSnackbar("Chat Restored", "${chat.getTitle()} has been restored to your chat list.");
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      safeAreaTop: true,
      appBar: BBAppBar(
        titleText: "Soft-Deleted Chats",
        leading: buildBackButton(context),
        backgroundColor: Colors.transparent,
        toolbarHeight: kIsDesktop ? 90 : 50,
      ),
      body: !_loaded
          ? Center(child: buildProgressIndicator(context))
          : _deletedChats.isEmpty
              ? Center(
                  child: Text(
                    "No soft-deleted chats found",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              : CustomScrollView(
                  physics: ThemeSwitcher.getScrollPhysics(),
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final chat = _deletedChats[index];
                          final deletedAt = chat.dateDeleted;
                          return Row(
                            children: [
                              Expanded(
                                child: ChatCreatorTile(
                                  key: ValueKey(chat.guid),
                                  title: chat.getTitle(),
                                  subtitle: deletedAt != null ? "Deleted: ${buildDate(deletedAt)}" : "Soft-deleted",
                                  chat: chat,
                                  showTrailing: false,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: TextButton(
                                  onPressed: () => _restore(chat),
                                  child: const Text("Restore"),
                                ),
                              ),
                            ],
                          );
                        },
                        childCount: _deletedChats.length,
                      ),
                    ),
                  ],
                ),
    );
  }
}
