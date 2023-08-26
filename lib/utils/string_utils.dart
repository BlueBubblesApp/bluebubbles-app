String cleansePhoneNumber(String phoneNumber) {
  // We only want numbers & the plus sign
  final regExp = RegExp(r"[^0-9\+]");
  return phoneNumber.replaceAll(regExp, '');
}