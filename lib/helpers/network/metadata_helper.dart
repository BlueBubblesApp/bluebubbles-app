import 'dart:async';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:universal_io/io.dart';

class MetadataHelper {
  static bool mapIsNotEmpty(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data.containsKey("title") && data["title"] != null;
  }

  static bool isNotEmpty(Metadata? data) {
    return data?.title != null || data?.description != null || data?.image != null;
  }

  static final Map<String, Completer<Metadata?>> _metaCache = {};

  static Future<Metadata?> fetchMetadata(Message message) async {
    Metadata? data;
    // If we have a cached item for this already, return that future
    if (_metaCache.containsKey(message.guid)) {
      return _metaCache[message.guid]!.future;
    }

    // Create a new completer for this request
    Completer<Metadata?> completer = Completer();
    _metaCache[message.guid!] = completer;

    // Get the URL
    String url = message.url!;
    if (!url.startsWith("http")) {
      url = "https://$url";
    }
    try {
      data = await MetadataFetch.extract(url);
    } catch (ex) {
      Logger.error('An error occurred while fetching URL Preview Metadata: ${ex.toString()}');
    }

    // If the everything in the metadata is null or empty, try to manually parse
    if (data?.toMap().values.where((e) => !isNullOrEmpty(e)!).isEmpty ?? true) {
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
    // In case the image is just a relative URL path
    } else if (imageData.startsWith('/')) {
      data?.image = '$url$imageData';
    }

    // Remove title or description if either are the "null" string
    if (data?.title == "null") data?.title = null;
    if (data?.description == "null") data?.description = null;

    // Set the OG URL
    data?.url = url;

    // Delete from the cache after 15 seconds (arbitrary)
    Future.delayed(const Duration(seconds: 15), () {
      if (_metaCache.containsKey(message.guid)) {
        _metaCache.remove(message.guid);
      }
    });

    // Tell everyone that it's complete
    completer.complete(data);
    return completer.future;
  }

  /// Manually tries to parse out metadata from a given [url]
  static Future<Metadata> _manuallyGetMetadata(String url) async {
    Metadata meta = Metadata();

    try {
      final response = await http.dio.get(url, options: Options(headers: {
        // pretend to be a social media crawler
        "User-Agent": "Mozilla/5.0 (Windows NT 6.1; rv:6.0) Gecko/20110814 Firefox/6.0 Google (+https://developers.google.com/+/web/snippet/)"
      }));
      if (response.headers.value('content-type')?.startsWith("image/") ?? false) {
        meta.image = url;
      }
      final document = parser.parse(response.data);
      final props = document.head?.children
          .where((e) => e.localName == "meta" && e.attributes["property"].toString().contains("og:"))
          .map((e) => MapEntry(e.attributes["property"], e.attributes["content"])).toList() ?? [];
      for (MapEntry entry in props) {
        if (entry.key == "og:title") {
          meta.title = entry.value;
        } else if (entry.key == "og:description") {
          meta.description = entry.value;
        } else if (entry.key == "og:image") {
          meta.image = entry.value;
        } else if (entry.key == "og:video" && meta.image != null) {
          meta.image = entry.value;
        } else if (entry.key == "og:url") {
          meta.url = entry.value;
        }
      }
    } on HandshakeException catch (ex) {
      meta.title = 'Invalid SSL Certificate';
      meta.description = ex.message;
    } catch (ex) {
      meta.title = ex.toString();
      Logger.error('Failed to manually get metadata: ${ex.toString()}');
    }

    return meta;
  }
}
