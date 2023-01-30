import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';

Future<bool> needsMigrationForUniqueService(Future chatLoader) async {
  await chatLoader;
  List<Chat> existingChats = List<Chat>.from(chats.chats);
  List<Handle> existingHandles = Handle.find();

  // Extract DMs (this won't apply to group chats or emails)
  List<Chat> dms = existingChats.where((element) => !element.isGroup && !element.guid.contains('@')).toList();

  // Create a mapping of address -> services for the existing chats
  Map<String, List<String>> chatServices = {};
  for (Chat c in dms) {
    List<String> guidSplit = c.guid.split(';-;');
    String service = guidSplit[0];
    String address = guidSplit[1];

    if (!chatServices.containsKey(address)) {
      chatServices[address] = [];
    }

    if (!chatServices[address]!.contains(service)) {
      List<String> currentServices = chatServices[address]!;
      currentServices.add(service);
      chatServices[address] = currentServices;
    }
  }

  // Check if the chats with both an SMS version and iMessage version have corresponding handles
  for (final item in chatServices.entries) {
    if (item.value.length <= 1 || !item.value.contains("SMS")) continue;

    // If there are less than 2 handles for the given chat, then we need to migrate.
    // Having less than 2 handles, but having > 1 chats for the same address means
    // the different chats got merged (by service).
    List<Handle> matchingHandles = existingHandles.where((element) => element.address == item.key).toList();
    if (matchingHandles.length < 2) {
      return true;
    }
  }


  return false;
}