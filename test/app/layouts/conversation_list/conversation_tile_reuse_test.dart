import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tile controller only reads the chat from its state; the real ChatState
/// needs app services at construction.
class _ChatState implements ChatState {
  _ChatState(this.chat);

  @override
  final Chat chat;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Chat chat() => Chat(id: 1, guid: "chat-a", hasUnreadMessage: false);

  test("a reused tile controller selects into the list that reuses it", () {
    // Tile controllers outlive the list that created them: the iOS skin builds
    // them without a selection handler, and the main list's stay registered
    // after the chat is archived.
    final mainList = ConversationListController(showArchivedChats: false, showUnknownSenders: false);
    final archivedList = ConversationListController(showArchivedChats: true, showUnknownSenders: false);
    final c = chat();
    final tile = ConversationTileController(chatState: _ChatState(c), listController: mainList);

    void select(bool selected) => selected
        ? archivedList.selectedChats.add(c)
        : archivedList.selectedChats.removeWhere((e) => e.guid == c.guid);
    ConversationTile.adoptSelectHandler(tile, select, archivedList);

    expect(tile.onSelect, same(select));
    expect(tile.listController, same(archivedList));
    tile.onSelect!(!tile.isSelected);
    expect(tile.isSelected, isTrue);
    // A second long-press deselects instead of adding the chat twice.
    tile.onSelect!(!tile.isSelected);
    expect(archivedList.selectedChats, isEmpty);
    expect(mainList.selectedChats, isEmpty);
  });

  test("a tile without a selection handler leaves the reused controller alone", () {
    final mainList = ConversationListController(showArchivedChats: false, showUnknownSenders: false);
    final otherList = ConversationListController(showArchivedChats: true, showUnknownSenders: false);
    void select(bool _) {}
    final tile = ConversationTileController(chatState: _ChatState(chat()), listController: mainList, onSelect: select);

    ConversationTile.adoptSelectHandler(tile, null, otherList);

    expect(tile.onSelect, same(select));
    expect(tile.listController, same(mainList));
  });
}
