// https://apple.stackexchange.com/a/205805

final Map<String, String> emoticonMap = {
  ":)": "😊",
  ":-)": "😊",
  ";)": "😉",
  ":(": "😟",
  ":-(": "😟",
  "B)": "😎",
  "B-)": "😎",
  ":D": "😃",
  ":-D": "😃",
  "D:": "😩",
  "D-:": "😩",
  ":d": "😋",
  ":-d": "😋",
  ";p": "😜",
  ":p": "😛",
  ":-p": "😛",
  ":o": "😮",
  ":-o": "😮",
  ":s": "😖",
  ":-s": "😖",
  ":x": "😶",
  ":-x": "😶",
  ":|": "😐",
  ":-|": "😐",
  ":/": "😕",
  ":-/": "😕",
  ":[": "😳",
  ":-[": "😳",
  ":>": "😏",
  ":->": "😏",
  ":@": "😷",
  ":-@": "😷",
  ":*": "😘",
  ":-*": "😘",
  ":!": "😬",
  ":-!": "😬",
  "o:)": "😇",
  "o:-)": "😇",
  ">:o": "😠",
  ">:-o": "😠",
  ">:)": "😈",
  ">:-)": "😈",
  ":3": "😺",
  "(y)": "👍",
  "(n)": "👎",
  "<3": "❤️",
};

final RegExp emoticonRegex = RegExp(
    "(?<=^|\\s)"
    "(?:${emoticonMap.keys.map((key) => key.replaceAllMapped(RegExp(r"[-\/\\^$*+?.()|[\]{}]", multiLine: true), (match) => "\\${match.group(0)}")).join("|")})"
    "(?=\\s)",
    multiLine: true);

// Replace all emoji and return the text, and the offsets and length differences of the replaced emoticons
(String newText, List<(int, int)> offsetsAndDifferences) replaceEmoticons(String text) {
  List<(int, int)> offsets = [];
  text = text.replaceAllMapped(emoticonRegex, (match) {
    String emoji = emoticonMap[match.group(0)]!;
    offsets.add((match.start, match.group(0)!.length - emoji.length));
    return emoji;
  });

  return (text, offsets);
}
