import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:collection/collection.dart';
import 'package:get/get_utils/src/extensions/string_extensions.dart';

class ChatCreatorUtils {
  static const List<int> _phoneMatchLengths = <int>[15, 14, 13, 12, 11, 10, 9, 8, 7];

  static List<ContactV2> filterContacts(List<ContactV2> contacts, String query) {
    return contacts
        .where((e) =>
            e.computedDisplayName.toLowerCase().contains(query) ||
            (e.nickname?.toLowerCase().contains(query) ?? false) ||
            e.phoneNumbers.firstWhereOrNull((p) => cleansePhoneNumber(p.number.toLowerCase()).contains(query)) !=
                null ||
            e.emailAddresses.firstWhereOrNull((email) => email.address.toLowerCase().contains(query)) != null)
        .toList();
  }

  static List<Chat> filterChats(List<Chat> chats, String query, ChatServiceType selectedService) {
    return chats
        .where(
          (chat) =>
              (selectedService.isIMessageService == chat.isIMessage) &&
              (chat.getTitle().toLowerCase().contains(query) ||
                  chat.handles.firstWhereOrNull((handle) =>
                          handle.address.contains(query) || handle.displayName.toLowerCase().contains(query)) !=
                      null),
        )
        .toList();
  }

  static bool chatMatchesSelectedContacts(Chat chat, List<String> selectedAddresses) {
    if (chat.handles.length != selectedAddresses.length) return false;

    int matches = 0;
    for (final address in selectedAddresses) {
      for (final participant in chat.handles) {
        if (addressesMatch(address, participant.address)) {
          matches += 1;
          break;
        }
      }
    }

    return matches == selectedAddresses.length;
  }

  /// Compares two handle addresses (phone numbers or emails), tolerating
  /// differing phone number formats (country code, punctuation, etc).
  static bool addressesMatch(String a, String b) {
    if (a.isEmail && !b.isEmail) return false;
    if (a == b) return true;

    final numeric = a.numericOnly();
    return _phoneMatchLengths.contains(numeric.length) && cleansePhoneNumber(b).endsWith(numeric);
  }
}
