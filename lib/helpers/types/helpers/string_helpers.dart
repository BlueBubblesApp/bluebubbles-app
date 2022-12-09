import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:html/parser.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

String randomString(int length) =>
    String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(Random().nextInt(_chars.length))));

String sanitizeString(String? input) {
  return input?.replaceAll(String.fromCharCode(65532), '') ?? "";
}

bool isNullOrEmptyString(String? input) {
  return sanitizeString(input).isEmpty;
}

List<RegExpMatch> parseLinks(String text) {
  return urlRegex.allMatches(text).toList();
}

String stripHtmlTags(String htmlString) {
  final document = parse(htmlString);
  return parse(document.body!.text).documentElement!.text;
}