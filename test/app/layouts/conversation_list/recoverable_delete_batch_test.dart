import 'package:bluebubbles/app/layouts/conversation_list/helpers/recoverable_delete_batch.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

Chat _chat(String guid, {int? id}) => Chat(id: id ?? guid.hashCode, guid: guid, hasUnreadMessage: false);

class _RecordingConversationListController extends ConversationListController {
  _RecordingConversationListController() : super(showArchivedChats: false, showUnknownSenders: false);

  int selectionUpdates = 0;

  @override
  void updateSelectedChats() => selectionUpdates++;
}

void main() {
  test('mixed batch runs sequentially, rebinds failures, replaces selection once, and emits one summary', () async {
    final first = _chat('first');
    final failedCaptured = _chat('failed', id: 2);
    final failedRestored = _chat('failed', id: 22);
    final third = _chat('third');
    final calls = <String>[];
    final replacements = <List<Chat>>[];
    final notices = <String>[];

    final result = await coordinateRecoverableDeleteBatch(
      selectedChats: [first, failedCaptured, third],
      deleteChat: (chat) async {
        calls.add(chat.guid);
        return chat.guid != 'failed';
      },
      currentChat: (guid) => guid == 'failed' ? failedRestored : null,
      replaceSelection: (chats) => replacements.add(List<Chat>.of(chats)),
      showNotice: (title, message, type) => notices.add('$title|$message|${type.name}'),
    );

    expect(calls, ['first', 'failed', 'third']);
    expect(result.total, 3);
    expect(result.accepted, 2);
    expect(result.failed, 1);
    expect(result.failedChats, [same(failedRestored)]);
    expect(replacements, [
      [same(failedRestored)],
    ]);
    expect(notices, [
      'Deletion requests started|2 of 3 deletion requests started. '
          '1 conversation could not be requested and remains selected.|error',
    ]);
  });

  test('empty selection does no work and emits no notice', () async {
    var deletes = 0;
    var replacements = 0;
    var notices = 0;

    final result = await coordinateRecoverableDeleteBatch(
      selectedChats: const [],
      deleteChat: (_) async {
        deletes++;
        return true;
      },
      currentChat: (_) => null,
      replaceSelection: (_) => replacements++,
      showNotice: (_, _, _) => notices++,
    );

    expect((result.total, result.accepted, result.failed), (0, 0, 0));
    expect(deletes, 0);
    expect(replacements, 0);
    expect(notices, 0);
  });

  test('all accepted summary uses started copy with singular and plural grammar', () async {
    for (final testCase in <({List<Chat> chats, String notice})>[
      (chats: [_chat('one')], notice: 'Deletion request started|1 deletion request started.|success'),
      (chats: [_chat('one'), _chat('two')], notice: 'Deletion requests started|2 deletion requests started.|success'),
    ]) {
      final notices = <String>[];
      final replacements = <List<Chat>>[];
      final result = await coordinateRecoverableDeleteBatch(
        selectedChats: testCase.chats,
        deleteChat: (_) async => true,
        currentChat: (_) => null,
        replaceSelection: (chats) => replacements.add(chats),
        showNotice: (title, message, type) => notices.add('$title|$message|${type.name}'),
      );

      expect(result.accepted, testCase.chats.length);
      expect(result.failed, 0);
      expect(replacements, [isEmpty]);
      expect(notices, [testCase.notice]);
    }
  });

  test('all failed summary keeps captured chats and uses singular and plural grammar', () async {
    for (final testCase in <({List<Chat> chats, String notice})>[
      (
        chats: [_chat('one')],
        notice:
            'Deletion request not started|The deletion request could not be started. '
            '1 conversation remains selected.|error',
      ),
      (
        chats: [_chat('one'), _chat('two')],
        notice:
            'Deletion requests not started|2 deletion requests could not be started. '
            '2 conversations remain selected.|error',
      ),
    ]) {
      final notices = <String>[];
      final replacements = <List<Chat>>[];
      final result = await coordinateRecoverableDeleteBatch(
        selectedChats: testCase.chats,
        deleteChat: (_) async => false,
        currentChat: (_) => null,
        replaceSelection: (chats) => replacements.add(chats),
        showNotice: (title, message, type) => notices.add('$title|$message|${type.name}'),
      );

      expect(result.accepted, 0);
      expect(result.failedChats, testCase.chats);
      expect(replacements.single, testCase.chats);
      expect(notices, [testCase.notice]);
    }
  });

  test('controller deletion operation retains restored failures and updates selection once', () async {
    GetIt.I.registerSingleton<SettingsService>(SettingsService()..settings = Settings());
    addTearDown(GetIt.I.reset);
    final controller = _RecordingConversationListController();
    final capturedFailure = _chat('failed', id: 4);
    final restoredFailure = _chat('failed', id: 44);
    controller.selectedChats.addAll([_chat('accepted'), capturedFailure]);
    final notices = <String>[];

    final result = await controller.deleteSelectedChats(
      deleteChat: (chat) async => chat.guid != 'failed',
      currentChat: (guid) => guid == 'failed' ? restoredFailure : null,
      showNotice: (title, message, type) => notices.add('$title|$message|${type.name}'),
    );

    expect(result.accepted, 1);
    expect(controller.selectedChats, [same(restoredFailure)]);
    expect(controller.selectionUpdates, 1);
    expect(notices, hasLength(1));
  });
}
