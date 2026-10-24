import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  group('reading the spam flag from server data', () {
    test('a chat Messages filed under Spam', () {
      expect(Chat.fromMap({'guid': 'chat', 'isFilteredAsSpam': true}).isFilteredAsSpam, isTrue);
    });

    test('a chat Messages did not file under Spam', () {
      expect(Chat.fromMap({'guid': 'chat', 'isFilteredAsSpam': false}).isFilteredAsSpam, isFalse);
    });

    test('a server that predates the flag leaves it unknown', () {
      expect(Chat.fromMap({'guid': 'chat'}).isFilteredAsSpam, isNull);
    });

    test('the flag survives the toMap round trip used to cross isolates', () {
      final chat = Chat.fromMap({'guid': 'chat', 'isFilteredAsSpam': true});
      expect(Chat.fromMap(chat.toMap()).isFilteredAsSpam, isTrue);
    });
  });

  group('merging server data into a stored chat', () {
    Chat stored(bool? isFilteredAsSpam) => Chat(guid: 'chat', isFilteredAsSpam: isFilteredAsSpam);

    test('data without the flag keeps the stored verdict', () {
      final chat = stored(true);

      expect(chat.mergeSpamFlag(Chat.fromMap({'guid': 'chat'})), isFalse);
      expect(chat.isFilteredAsSpam, isTrue);
    });

    test('data without the flag keeps the stored verdict after a toMap round trip', () {
      final chat = stored(true);
      final incoming = Chat.fromMap(Chat.fromMap({'guid': 'chat'}).toMap());

      expect(chat.mergeSpamFlag(incoming), isFalse);
      expect(chat.isFilteredAsSpam, isTrue);
    });

    test('data with the flag overwrites the stored verdict', () {
      final chat = stored(true);

      expect(chat.mergeSpamFlag(Chat.fromMap({'guid': 'chat', 'isFilteredAsSpam': false})), isTrue);
      expect(chat.isFilteredAsSpam, isFalse);
    });

    test('the first verdict is stored', () {
      final chat = stored(null);

      expect(chat.mergeSpamFlag(Chat.fromMap({'guid': 'chat', 'isFilteredAsSpam': true})), isTrue);
      expect(chat.isFilteredAsSpam, isTrue);
    });
  });

  group('notifications', () {
    setUpAll(() => GetIt.I.registerSingleton<SettingsService>(SettingsService()..settings = Settings()));
    tearDownAll(() => GetIt.I.reset());

    test('a chat Messages filed under Spam stays silent', () {
      expect(Chat(guid: 'chat', isFilteredAsSpam: true).shouldMuteNotification(null), isTrue);
    });

    test('other chats still notify', () {
      expect(Chat(guid: 'chat', isFilteredAsSpam: false).shouldMuteNotification(null), isFalse);
      expect(Chat(guid: 'chat').shouldMuteNotification(null), isFalse);
    });
  });
}
