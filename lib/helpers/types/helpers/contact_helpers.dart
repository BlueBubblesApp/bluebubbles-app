import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:get/get.dart';

String formatPhoneNumber(dynamic item) {
  String cc = Get.deviceLocale?.countryCode ?? "US";
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
  if (isNullOrEmpty(address) || address!.isEmail || address.contains("urn:biz")) return address ?? "Unknown";
  address = address.trim();

  String? formatted;
  try {
    final parsed = PhoneNumberUtil.instance.parse(address, address.startsWith("+") ? null : cc);
    formatted = PhoneNumberUtil.instance.format(parsed, PhoneNumberFormat.international);
  } catch (_) {}

  return formatted ?? address;
}

/// Generate multiple normalized variants of a phone number to handle country code mismatches
///
/// Returns a set of normalized phone numbers including:
/// - The original normalized number (digits + plus sign only)
/// - Variant without country code (if one exists)
/// - Variant with country code removed but assuming it started with +
///
/// This handles cases where:
/// - Contact has "1234567890" but Handle has "+11234567890"
/// - Contact has "+11234567890" but Handle has "1234567890"
/// - Works with any country code, not just +1
Set<String> getPhoneNumberVariants(String phone) {
  final variants = <String>{};
  final normalized = ContactV2.normalizePhoneNumber(phone);

  if (normalized.isEmpty) return variants;

  // Always include the base normalized version
  variants.add(normalized);

  // If it starts with +, add variant without the +
  if (normalized.startsWith('+')) {
    variants.add(normalized.substring(1));

    // Also try removing common country codes (1-3 digits after +)
    // Country codes can be 1-3 digits (e.g., +1, +44, +852, +1246)
    for (int i = 1; i <= 3 && i < normalized.length; i++) {
      final withoutCountryCode = normalized.substring(i + 1);
      if (withoutCountryCode.isNotEmpty) {
        variants.add(withoutCountryCode);
      }
    }
  } else {
    // If no +, try adding + and common country code lengths
    // This handles cases where the stored number doesn't have + but the contact does
    variants.add('+$normalized');

    // Try removing 1-3 digit prefixes as potential country codes
    for (int i = 1; i <= 3 && i < normalized.length; i++) {
      final withoutPrefix = normalized.substring(i);
      if (withoutPrefix.isNotEmpty) {
        variants.add(withoutPrefix);
        variants.add('+$withoutPrefix');
      }
    }
  }

  return variants;
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
