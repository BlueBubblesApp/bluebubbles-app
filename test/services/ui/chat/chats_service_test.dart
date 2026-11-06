import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/ui/chat/chats_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingChat extends Chat {
  _RecordingChat() : super(id: 1, guid: 'test-chat', hasUnreadMessage: false);

  int toggleCallCount = 0;
  bool? recordedHasUnread;
  bool? recordedForce;
  bool? recordedClearLocalNotifications;
  bool? recordedPrivateMark;

  @override
  Future<Chat> toggleHasUnreadAsync(
    bool hasUnread, {
    bool force = false,
    bool clearLocalNotifications = true,
    bool privateMark = true,
  }) async {
    toggleCallCount++;
    recordedHasUnread = hasUnread;
    recordedForce = force;
    recordedClearLocalNotifications = clearLocalNotifications;
    recordedPrivateMark = privateMark;
    return this;
  }
}

void main() {
  group('shouldApplyServerUnreadUpdate', () {
    const cases = <({bool localUnread, bool serverUnread, bool shouldApply})>[
      (localUnread: false, serverUnread: false, shouldApply: true),
      (localUnread: false, serverUnread: true, shouldApply: true),
      (localUnread: true, serverUnread: false, shouldApply: true),
      (localUnread: true, serverUnread: true, shouldApply: false),
    ];

    for (final testCase in cases) {
      test('local unread ${testCase.localUnread}, server unread ${testCase.serverUnread} '
          '${testCase.shouldApply ? 'applies' : 'short-circuits'}', () {
        expect(
          shouldApplyServerUnreadUpdate(localUnread: testCase.localUnread, serverUnread: testCase.serverUnread),
          testCase.shouldApply,
        );
      });
    }
  });

  test('a server read forces local persistence and notification cleanup without a private mark', () async {
    final chat = _RecordingChat();

    await ChatsService().setChatHasUnreadFromServer(chat, false);

    expect(chat.toggleCallCount, 1);
    expect(chat.recordedHasUnread, isFalse);
    expect(chat.recordedForce, isTrue);
    expect(chat.recordedClearLocalNotifications, isTrue);
    expect(chat.recordedPrivateMark, isFalse);
  });
}
