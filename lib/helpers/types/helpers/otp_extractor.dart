// Detection of one-time passcodes (2FA / verification codes) in message text.
//
// Kept as a pure, dependency-free top-level function so the matching rules can
// be reasoned about and exercised in isolation from the message pipeline.

/// Messages longer than this are never considered — real 2FA texts are short,
/// and a long message containing a stray number is almost certainly not one.
const int _maxTextLength = 500;

/// A 2FA-ish keyword must appear for any candidate to be considered. This is
/// what keeps order numbers, prices, and street addresses out of the clipboard.
final RegExp _keywordRegex = RegExp(
  r'\b('
  r'code|passcode|otp|one[\s-]?time|2fa|two[\s-]?factor|'
  r'verification|verify|verifying|authenticate|authentication|auth|'
  r'security|sign[\s-]?in|log[\s-]?in|login|pin'
  r')\b',
  caseSensitive: false,
);

/// A standalone run of 4-8 digits, optionally carrying a short alpha prefix
/// (Google sends `G-123456`). The lookarounds reject digits embedded in a
/// longer token, currency amounts, decimals, and thousands separators like
/// `1,234` -- while still allowing the trailing sentence punctuation that real
/// 2FA texts are full of ("your code is 123456." / "123456, valid 10 min").
final RegExp _candidateRegex =
    RegExp(r'(?<![\w$-])(?<!\d[.,])(?:([A-Za-z]{1,2})-)?(\d{4,8})(?![\w-])(?![.,]\d)');

/// Preference order for candidate length. Six digits is overwhelmingly the
/// common case; four-digit codes are the most collision-prone so they rank last.
const List<int> _lengthPreference = [6, 8, 7, 5, 4];

/// Returns the one-time passcode contained in [text], or `null` if [text]
/// doesn't look like a 2FA message.
///
/// Detection is deliberately conservative: a 2FA-ish keyword must be present,
/// and among the qualifying digit runs the most passcode-shaped one wins. It is
/// far better to miss a code than to silently overwrite the user's clipboard
/// with an order number.
String? extractOtpCode(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.length > _maxTextLength) return null;

  // Gate on a 2FA keyword before looking at any digits at all.
  final keywordMatches = _keywordRegex.allMatches(trimmed).toList();
  if (keywordMatches.isEmpty) return null;

  final candidates = <_Candidate>[];
  for (final match in _candidateRegex.allMatches(trimmed)) {
    final digits = match.group(2)!;

    // A bare 4-digit value in this range is a year, not a passcode.
    if (digits.length == 4) {
      final asInt = int.tryParse(digits);
      if (asInt != null && asInt >= 1900 && asInt <= 2100) continue;
    }

    // Distance to the nearest keyword — used to break ties between candidates
    // of equally-preferred length ("code 123456, ref 987654").
    final distance = keywordMatches
        .map((k) => (match.start - k.end).abs())
        .reduce((a, b) => a < b ? a : b);

    candidates.add(_Candidate(digits: digits, distance: distance));
  }
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final rankA = _lengthPreference.indexOf(a.digits.length);
    final rankB = _lengthPreference.indexOf(b.digits.length);
    if (rankA != rankB) return rankA.compareTo(rankB);
    return a.distance.compareTo(b.distance);
  });

  return candidates.first.digits;
}

class _Candidate {
  final String digits;
  final int distance;

  const _Candidate({required this.digits, required this.distance});
}
