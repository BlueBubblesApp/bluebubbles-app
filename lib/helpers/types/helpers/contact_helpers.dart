import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/foundation.dart';
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
    formatted = parsed.getFormattedNsn(isoCode: IsoCode.values.firstWhereOrNull((element) => describeEnum(element) == cc));
  } catch (_) {}

  return formatted ?? address;
}

List<String> getUniqueNumbers(Iterable<String> numbers) {
  List<String> phones = [];
  for (String phone in numbers) {
    bool exists = false;
    for (String current in phones) {
      if (phone.numericOnly() == current.numericOnly()) {
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

List<String> getUniqueEmails(Iterable<String> list) {
  List<String> emails = [];
  for (String email in list) {
    bool exists = false;
    for (String current in emails) {
      if (email.trim() == current.trim()) {
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