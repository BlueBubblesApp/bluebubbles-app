/// Masks the values of sensitive auth query parameters (`guid` and `password`)
/// anywhere they appear in a string (standalone URL or an error message
/// embedding a URL).  Each matched value is replaced with `***`.
///
/// The function is intentionally dependency-free and never throws — malformed
/// or empty input is returned unchanged.
String maskUrlPassword(String input) {
  if (input.isEmpty) return input;
  try {
    return input.replaceAllMapped(
      RegExp(r'''([?&])(guid|password)=([^&\s#'",)}\]]*)''', caseSensitive: false),
      (m) => '${m[1]}${m[2]}=***',
    );
  } catch (_) {
    return input;
  }
}
