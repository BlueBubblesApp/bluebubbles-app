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

/// The fewest digits a number may have left once a guessed country code is dropped from it. The shortest national
/// numbers in real use are 7 digits (e.g. Iceland), while carrier short codes have 3–6 digits. Without this floor, two
/// unrelated short codes match whenever their last digits agree once 1–3 "country code" digits are stripped from both
/// sides (32789 and 73889 both become "89").
const int minPhoneNumberDigitsWithoutCountryCode = 7;

/// Normalized forms of [phone] that the contact sync treats as the same number, so a contact saved as "1234567890"
/// matches a handle "+11234567890" and the other way round, for any country code length (1–3 digits).
///
/// Two numbers are the same when their variant sets share an element. Variants without a country code are only made
/// when at least [minPhoneNumberDigitsWithoutCountryCode] digits remain, so a short code only ever matches itself
/// (with or without a leading "+").
Set<String> phoneNumberVariants(String phone) {
  final variants = <String>{};
  final normalized = ContactV2.normalizePhoneNumber(phone);
  if (normalized.isEmpty) return variants;

  // Always include the base normalized version, and the same digits with and without a leading +
  variants.add(normalized);
  final digits = normalized.startsWith('+') ? normalized.substring(1) : normalized;
  variants.add(digits);
  variants.add('+$digits');

  // Try removing 1-3 leading digits as a possible country code (e.g. +1, +44, +852)
  for (int i = 1; i <= 3; i++) {
    final withoutCountryCode = digits.length > i ? digits.substring(i) : '';
    if (withoutCountryCode.length < minPhoneNumberDigitsWithoutCountryCode) break;
    variants.add(withoutCountryCode);
    // Without a +, the stored number may itself be the one missing a + (see the original contact sync behavior)
    if (!normalized.startsWith('+')) variants.add('+$withoutCountryCode');
  }

  return variants;
}
