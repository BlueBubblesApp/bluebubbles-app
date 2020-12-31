import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;

class MetadataHelper {
  static bool mapIsNotEmpty(Map<String, dynamic> data) {
    if (data == null) return false;
    return data.containsKey("title") &&
        data["title"] != null &&
        data.containsKey("description") &&
        data["description"] != null &&
        data.containsKey("image") &&
        data["image"] != null;
  }

  static bool isNotEmpty(Metadata data) {
    return data?.title != null ||
        data?.description != null ||
        data?.image != null;
  }

  static Map<String, Completer<Metadata>> _metaCache = {};
  static Future<Metadata> fetchMetadata(Message message) async {
    Metadata data;

    if (message == null || isEmptyString(message.text)) return null;

    // If we have a cached item for this already, return that future
    if (_metaCache.containsKey(message.guid)) {
      return _metaCache[message.guid].future;
    }

    // Create a new completer for this request
    Completer<Metadata> completer = new Completer();
    _metaCache[message.guid] = completer;

    // Make sure there is a schema with the URL
    String url = message.text;
    if (!url.toLowerCase().startsWith("http://") &&
        !url.toLowerCase().startsWith("https://")) {
      url = "https://" + url;
    }

    String newUrl = MetadataHelper._reformatUrl(url);

    // Handle specific cases
    bool alreadyManual = false;
    if (newUrl.contains('https://www.youtube.com/oembed')) {
      // Manually request this URL
      var response = await http.get(newUrl);

      // Manually load it into a metadata object via JSON
      data = Metadata.fromJson(jsonDecode(response.body));

      // Set the URL to the original URL
      data.url = url;
    } else if (newUrl.contains("https://publish.twitter.com/oembed")) {
      // Manually request this URL
      var response = await http.get(newUrl);

      // Manually load it into a metadata object via JSON
      Map res = jsonDecode(response.body);
      data = new Metadata();
      data.title = (res.containsKey("author_name")) ? res["author_name"] : "";
      data.description = (res.containsKey("html"))
          ? stripHtmlTags(res["html"].replaceAll("<br>", "\n")).trim()
          : "";

      // Set the URL to the original URL
      data.url = url;
    } else if (url.contains("redd.it/")) {
      var response = await http.get(url);
      var document = responseToDocument(response);

      // Since this is a short-URL, we need to get the actual URL out
      String href;
      for (dom.Element i in document?.head?.children ?? []) {
        // Skip over all links
        if (i.localName != "link") continue;

        // Find an href and save it
        for (var entry in i.attributes.entries) {
          String prop = entry.key as String;
          if (prop != "href" ||
              entry.value.contains("amp.") ||
              !entry.value.contains("reddit.com")) continue;
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
      data.url = url;
      alreadyManual = true;
    } else {
      data = await extract(url);
    }

    // If the data or title was null, try to manually parse
    if (!alreadyManual && isNullOrEmpty(data?.title)) {
      data = await MetadataHelper._manuallyGetMetadata(url);
      data.url = url;
    }

    // Remove the image data if the image data links to an "empty image"
    String imageData = data?.image ?? "";
    if (imageData.contains("renderTimingPixel.png") ||
        imageData.contains("fls-na.amazon.com")) {
      data?.image = null;
    }

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
    if (url.contains('youtube.com/watch?v=') || url.contains("youtu.be/")) {
      return "https://www.youtube.com/oembed?url=$url";
    } else if (url.contains("twitter.com") && url.contains("/status/")) {
      return "https://publish.twitter.com/oembed?url=$url";
    } else {
      return url;
    }
  }

  /// Manually tries to parse out metadata from a given [url]
  static Future<Metadata> _manuallyGetMetadata(String url) async {
    Metadata meta = new Metadata();

    var response = await http.get(url);
    var document = responseToDocument(response);

    for (dom.Element i in document.head?.children ?? []) {
      if (i.localName != "meta") continue;
      for (var entry in i.attributes.entries) {
        String prop = entry.key as String;
        String value = entry.value;
        if (prop != "property" && prop != "name") continue;

        if (value.contains("title")) {
          meta.title = i.attributes["content"];
        } else if (value.contains("description")) {
          meta.description = i.attributes["content"];
        } else if (value == "og:image") {
          meta.image = i.attributes["content"];
        }
      }
    }

    return meta;
  }
}
