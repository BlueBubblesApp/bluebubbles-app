import 'package:emojis/emoji.dart';

final Map<String, Emoji> emojiNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.shortName, e)));
final Map<String, Emoji> emojiFullNames = Map.fromEntries(Emoji.all().map((e) => MapEntry(e.name, e)));
