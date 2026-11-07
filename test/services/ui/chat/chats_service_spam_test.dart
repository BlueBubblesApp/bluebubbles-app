import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/services/ui/chat/chats_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Serves a fixed chat list; the real one is filled through ChatState, which
/// needs app services.
class _ChatsService extends ChatsService {
  _ChatsService(this.chats);

  final List<Chat> chats;

  @override
  List<Chat> get allChats => chats;
}

void main() {
  late Settings settings;

  setUp(() {
    settings = Settings();
    GetIt.I.registerSingleton<SettingsService>(SettingsService()..settings = settings);
  });
  tearDown(() => GetIt.I.reset());

  final spam = Chat(id: 1, guid: 'spam', isFilteredAsSpam: true, hasUnreadMessage: true);
  final archivedSpam = Chat(id: 2, guid: 'archived-spam', isArchived: true, isFilteredAsSpam: true);
  final chat = Chat(id: 3, guid: 'chat', isFilteredAsSpam: false, hasUnreadMessage: true);
  final archived = Chat(id: 4, guid: 'archived', isArchived: true);
  final service = _ChatsService([spam, archivedSpam, chat, archived]);

  List<String> guids(List<Chat> chats) => chats.map((e) => e.guid).toList();

  test('the main list leaves out chats Messages filed under Spam', () {
    expect(guids(service.getFilteredChats(showArchived: false, showUnknown: false)), ['chat']);
  });

  test('the archived list leaves them out too', () {
    expect(guids(service.getFilteredChats(showArchived: true, showUnknown: false)), ['archived']);
  });

  test('the unknown senders list leaves them out too', () {
    settings.filterUnknownSenders.value = true;

    expect(guids(service.getFilteredChats(showArchived: false, showUnknown: true)), ['chat']);
  });
}
