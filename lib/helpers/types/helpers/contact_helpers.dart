import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/global/contact_address.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:get/get.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

Future<String> formatPhoneNumber(dynamic item) async {
  String cc = countryCode ?? "US";
  String? address;

  // Set the address/country accordingly
  if (item is String?) {
    address = item;
  } else if (item is Handle?) {
    address = item?.address;
    cc = item?.country ?? cc;
  } else {
    return item.toString();
  }

  // If we don't have a valid address, or it's an email, return it
  if (isNullOrEmpty(address)! || address!.isEmail || address.contains("urn:biz")) return address ?? "Unknown";
  address = address.trim();

  String? formatted;
  try {
    final parsed = PhoneNumber.parse(address);
    formatted = parsed.getFormattedNsn(isoCode: IsoCode.values.firstWhereOrNull((element) => element.name == cc));
  } catch (_) {}

  return formatted ?? address;
}

List<ContactAddress> getUniqueNumbers(Iterable<ContactAddress> numbers) {
  List<ContactAddress> phones = [];
  for (ContactAddress phone in numbers) {
    bool exists = false;
    for (ContactAddress current in phones) {
      if (phone.address.numericOnly() == current.address.numericOnly()) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      phones.add(phone);
    }
  }

  return phones;
}

List<ContactAddress> getUniqueEmails(Iterable<ContactAddress> list) {
  List<ContactAddress> emails = [];
  for (ContactAddress email in list) {
    bool exists = false;
    for (ContactAddress current in emails) {
      if (email.address.trim() == current.address.trim()) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      emails.add(email);
    }
  }

  return emails;
}

String getDisplayName(String? displayName, String? firstName, String? lastName) {
  String? _displayName = (displayName?.isEmpty ?? false) ? null : displayName;
  return _displayName ?? [firstName, lastName].where((e) => e?.isNotEmpty ?? false).toList().join(" ");
}