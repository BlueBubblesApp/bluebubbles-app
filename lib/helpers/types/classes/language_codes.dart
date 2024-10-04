import 'package:collection/collection.dart';

const languageData = [
  {
    "name": "German",
    "longCode": "de",
  },
  {
    "name": "German (Germany)",
    "longCode": "de-DE",
  },
  {
    "name": "German (Austria)",
    "longCode": "de-AT",
  },
  {
    "name": "German (Swiss)",
    "longCode": "de-CH",
  },
  {
    "name": "English",
    "longCode": "en",
  },
  {
    "name": "English (US)",
    "longCode": "en-US",
  },
  {
    "name": "English (Australian)",
    "longCode": "en-AU",
  },
  {
    "name": "English (GB)",
    "longCode": "en-GB",
  },
  {
    "name": "English (Canadian)",
    "longCode": "en-CA",
  },
  {
    "name": "English (New Zealand)",
    "longCode": "en-NZ",
  },
  {
    "name": "English (South African)",
    "longCode": "en-ZA",
  },
  {
    "name": "Spanish",
    "longCode": "es",
  },
  {
    "name": "Spanish (voseo)",
    "longCode": "es-AR",
  },
  {
    "name": "French",
    "longCode": "fr",
  },
  {
    "name": "French (Canada)",
    "longCode": "fr-CA",
  },
  {
    "name": "French (Switzerland)",
    "longCode": "fr-CH",
  },
  {
    "name": "French (Belgium)",
    "longCode": "fr-BE",
  },
  {
    "name": "Dutch",
    "longCode": "nl",
  },
  {
    "name": "Dutch (Belgium)",
    "longCode": "nl-BE",
  },
  {
    "name": "Portuguese (Angola preAO)",
    "longCode": "pt-AO",
  },
  {
    "name": "Portuguese (Brazil)",
    "longCode": "pt-BR",
  },
  {
    "name": "Portuguese (Moçambique preAO)",
    "longCode": "pt-MZ",
  },
  {
    "name": "Portuguese (Portugal)",
    "longCode": "pt-PT",
  },
  {
    "name": "Portuguese",
    "longCode": "pt",
  },
  {
    "name": "Arabic",
    "longCode": "ar",
  },
  {
    "name": "Asturian",
    "longCode": "ast-ES",
  },
  {
    "name": "Belarusian",
    "longCode": "be-BY",
  },
  {
    "name": "Breton",
    "longCode": "br-FR",
  },
  {
    "name": "Catalan",
    "longCode": "ca-ES",
  },
  {
    "name": "Catalan (Valencian)",
    "longCode": "ca-ES-valencia",
  },
  {
    "name": "Catalan (Balearic)",
    "longCode": "ca-ES-balear",
  },
  {
    "name": "Danish",
    "longCode": "da-DK",
  },
  {
    "name": "Simple German",
    "longCode": "de-DE-x-simple-language",
  },
  {
    "name": "Greek",
    "longCode": "el-GR",
  },
  {
    "name": "Esperanto",
    "longCode": "eo",
  },
  {
    "name": "Persian",
    "longCode": "fa",
  },
  {
    "name": "Irish",
    "longCode": "ga-IE",
  },
  {
    "name": "Galician",
    "longCode": "gl-ES",
  },
  {
    "name": "Italian",
    "longCode": "it",
  },
  {
    "name": "Japanese",
    "longCode": "ja-JP",
  },
  {
    "name": "Khmer",
    "longCode": "km-KH",
  },
  {
    "name": "Polish",
    "longCode": "pl-PL",
  },
  {
    "name": "Romanian",
    "longCode": "ro-RO",
  },
  {
    "name": "Russian",
    "longCode": "ru-RU",
  },
  {
    "name": "Slovak",
    "longCode": "sk-SK",
  },
  {
    "name": "Slovenian",
    "longCode": "sl-SI",
  },
  {
    "name": "Swedish",
    "longCode": "sv",
  },
  {
    "name": "Tamil",
    "longCode": "ta-IN",
  },
  {
    "name": "Tagalog",
    "longCode": "tl-PH",
  },
  {
    "name": "Ukrainian",
    "longCode": "uk-UA",
  },
  {
    "name": "Chinese",
    "longCode": "zh-CN",
  },
  {
    "name": "Crimean Tatar",
    "longCode": "crh-UA",
  },
  {
    "name": "Norwegian (Bokmål)",
    "longCode": "nb",
  }
];

final List<(String, String)> languageNameAndCodes =
    languageData.map((d) => (d["name"]!, d["longCode"]!)).sorted((a, b) => a.$1.compareTo(b.$1));
