final RegExp _sensitiveQueryParam =
    RegExp(r'''([?&])(guid|password)=([^&\s#'",)}\]]*)''', caseSensitive: false);

/// Masks the values of sensitive auth query parameters (`guid` and `password`)
/// anywhere they appear in a string (standalone URL or an error message
/// embedding a URL).  Each matched value is replaced with `***`.
String maskUrlPassword(String input) {
  if (input.isEmpty) return input;
  return input.replaceAllMapped(_sensitiveQueryParam, (m) => '${m[1]}${m[2]}=***');
}
