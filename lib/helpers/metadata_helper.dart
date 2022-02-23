import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:universal_io/io.dart';

/// Adds getter/setter for the original [Response?.request.url]
extension HttpRequestData on Document? {
  static String _requestUrl = "";

  String get requestUrl {
    return _requestUrl;
  }

  set requestUrl(String newValue) {
    _requestUrl = newValue;
  }
}

class MetadataHelper {
  static bool mapIsNotEmpty(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data.containsKey("title") && data["title"] != null;
  }

  static bool isNotEmpty(Metadata? data) {
    return data?.title != null || data?.description != null || data?.image != null;
  }

  static Map<String, dynamic>? safeJsonDecode(String input) {
    try {
      return jsonDecode(input);
    } catch (ex) {
      return null;
    }
  }

  static final Map<String, Completer<Metadata>> _metaCache = {};

  static Future<Metadata?> fetchMetadata(Message? message) async {
    Metadata? data;

    if (message?.guid == null || isEmptyString(message!.text)) return null;

    // If we have a cached item for this already, return that future
    if (_metaCache.containsKey(message.guid)) {
      return _metaCache[message.guid]!.future;
    }

    // Create a new completer for this request
    Completer<Metadata> completer = Completer();
    _metaCache[message.guid!] = completer;

    // Make sure there is a schema with the URL
    String url = message.getUrl()!;
    if (!url.toLowerCase().startsWith("http://") && !url.toLowerCase().startsWith("https://")) {
      url = "https://" + url;
    }

    String originalUrl = url;
    Uri? newUrl = Uri.tryParse(MetadataHelper._reformatUrl(url));

    // Handle specific cases
    bool alreadyManual = false;
    if (newUrl != null && newUrl.toString().contains('https://www.youtube.com/oembed')) {
      // Manually request this URL
      var response = await http.get(newUrl);

      // Manually load it into a metadata object via JSON
      Map? json = MetadataHelper.safeJsonDecode(response.body);
      if (isNullOrEmpty(json)!) {
        completer.complete(Metadata());
        return completer.future;
      }

      data = Metadata();
      data.image = json!.containsKey("thumbnail_url") ? json["thumbnail_url"] : null;
      data.title = json.containsKey("title") ? json["title"] : null;
      data.description = json.containsKey("author_name") ? "User: ${json["author_name"]}" : null;

      // Set the URL to the original URL
      data.url = url;
    } else if (newUrl != null && newUrl.toString().contains("https://publish.twitter.com/oembed")) {
      // Manually request this URL
      var response = await http.get(newUrl);

      // Manually load it into a metadata object via JSON
      Map? res = MetadataHelper.safeJsonDecode(response.body);
      if (isNullOrEmpty(res)!) {
        completer.complete(Metadata());
        return completer.future;
      }

      data = Metadata();
      data.title = (res!.containsKey("author_name")) ? res["author_name"] : "";
      data.description = (res.containsKey("html")) ? stripHtmlTags(res["html"].replaceAll("<br>", "\n")).trim() : "";

      // Set the URL to the original URL
      data.url = url;
    } else if (newUrl != null && newUrl.toString().contains("redd.it/")) {
      var response = await http.get(newUrl);
      var document = MetadataFetch.responseToDocument(response);

      // Since this is a short-URL, we need to get the actual URL out
      String? href;
      for (var i in document?.head?.children ?? []) {
        // Skip over all links
        if (i.localName != "link") continue;

        // Find an href and save it
        for (var entry in i.attributes.entries) {
          String? prop = entry.key as String?;
          if (prop != "href" || entry.value.contains("amp.") || !entry.value.contains("reddit.com")) continue;
          href = entry.value;
          break;
        }

        // If we have an href, break out
        if (href != null) break;
      }

      if (href != null) {
        data = await MetadataHelper._manuallyGetMetadata(href);
        alreadyManual = true;
      }
    } else if (url.contains("linkedin.com/posts/")) {
      data = await MetadataHelper._manuallyGetMetadata(url);
      alreadyManual = true;
    } else {
      try {
        data = await MetadataFetch.extract(url);
      } catch (ex) {
        Logger.error('An error occurred while fetching URL Preview Metadata: ${ex.toString()}');
      }
    }

    // If the data or title was null, try to manually parse
    if (!alreadyManual && isNullOrEmpty(data?.title)!) {
      data = await MetadataHelper._manuallyGetMetadata(url);
    }

    // If the URL is supposedly to an actual image, set the image to the URL manually
    RegExp exp = RegExp(r"(.png|.jpg|.gif|.tiff|.jpeg)$");
    if (data?.image == null && data?.title == null && data!.url != null && exp.hasMatch(data.url!)) {
      data.image = data.url;
      data.title = "Image Preview";
    }

    // Remove the image data if the image data links to an "empty image"
    String imageData = data?.image ?? "";
    if (imageData.contains("renderTimingPixel.png") || imageData.contains("fls-na.amazon.com")) {
      data?.image = null;
    } else if (imageData.startsWith('//')) {
      data?.image = 'https:$imageData';
    }

    // Remove title or description if either are the "null" string
    if (data?.title == "null") data?.title = null;
    if (data?.description == "null") data?.description = null;

    // Set the OG URL
    data?.url = originalUrl;

    // Delete from the cache after 15 seconds (arbitrary)
    Future.delayed(Duration(seconds: 15), () {
      if (_metaCache.containsKey(message.guid)) {
        _metaCache.remove(message.guid);
      }
    });

    // Tell everyone that it's complete
    completer.complete(data);
    return completer.future;
  }

  static String _reformatUrl(String url) {
    if (url.contains('youtube.com/') || url.contains("youtu.be/")) {
      return "https://www.youtube.com/oembed?url=$url";
    } else if (url.contains("twitter.com") && url.contains("/status/")) {
      return "https://publish.twitter.com/oembed?url=$url";
    } else {
      return url;
    }
  }

  /// Takes an [http.Response] and returns a [html.Document]
  /// NOTE: I overrode this method from the library because there is
  /// a bug in the library's code with parsing the document.
  static Document? _responseToDocument(http.Response response) {
    if (response.statusCode != 200) {
      return null;
    }

    Document? document;
    try {
      document = parser.parse(response.body.toString());
      document.requestUrl = response.request!.url.toString();
    } catch (err) {
      Logger.error("Error parsing HTML document: ${err.toString()}");
      return document;
    }

    return document;
  }

  /// Manually tries to parse out metadata from a given [url]
  static Future<Metadata> _manuallyGetMetadata(String url) async {
    Metadata meta = Metadata();

    try {
      Uri uri = Uri.parse(url);
      var response = await http.get(uri);
      var document = MetadataHelper._responseToDocument(response);

      if (document == null) return meta;

      for (Element i in document.head?.children ?? []) {
        if (i.localName != "meta") continue;
        for (var entry in i.attributes.entries) {
          String? prop = entry.key as String?;
          String value = entry.value;
          if (prop != "property" && prop != "name") continue;

          if (value.contains("title")) {
            meta.title = i.attributes["content"];
          } else if (value.contains("description")) {
            meta.description = i.attributes["content"];
          } else if (value == "og:image") {
            meta.image = i.attributes["content"];
          } else if (value == "og:video") {
            meta.url = i.attributes["content"];
          }
        }
      }
    } on HandshakeException catch (ex) {
      meta.title = 'Invalid SSL Certificate';
      meta.description = ex.message;
    } catch (ex) {
      Logger.error('Failed to manually get metadata: ${ex.toString()}');
    }

    return meta;
  }
}
