import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:html/dom.dart' as html;
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

  /// Returns true when a metadata-fetch attempt has already completed without
  /// a network error (even if no image was found). Use this to avoid repeated
  /// fetches when the URL simply has no preview image.
  static bool hasAttemptedFetch(Map<String, dynamic>? metadata) {
    return metadata?['previewImageFetched'] == true;
  }

  static final Map<String, Completer<Metadata?>> _metaCache = {};

  /// Fetches OG metadata for [message]. By default the URL is parsed from
  /// [message.text] (standard link-preview flow); pass [urlOverride] to fetch
  /// metadata for a different URL instead (e.g. a share link embedded in a
  /// message's payload data rather than its text), keying the dedup cache off
  /// that URL instead of the message GUID.
  static Future<Metadata?> fetchMetadata(Message message, {String? urlOverride}) async {
    Metadata? data;
    final cacheKey = urlOverride ?? message.guid!;
    // If we have a cached item for this already, return that future
    if (_metaCache.containsKey(cacheKey)) {
      return _metaCache[cacheKey]!.future;
    }

    // Create a new completer for this request
    Completer<Metadata?> completer = Completer();
    _metaCache[cacheKey] = completer;

    // Get the URL
    String url = urlOverride ?? message.url!;
    if (!url.startsWith("http")) {
      url = "https://$url";
    }
    try {
      data = await MetadataFetch.extract(url);
    } on SocketException catch (ex, stack) {
      Logger.warn('Network unavailable while fetching URL preview metadata; retryable',
          error: ex, trace: stack, tag: 'MetadataHelper');
      completer.completeError(ex, stack);
      _metaCache.remove(message.guid);
      rethrow;
    } on TimeoutException catch (ex, stack) {
      Logger.warn('Timeout while fetching URL preview metadata; retryable',
          error: ex, trace: stack, tag: 'MetadataHelper');
      completer.completeError(ex, stack);
      _metaCache.remove(message.guid);
      rethrow;
    } catch (ex, stack) {
      Logger.error('An error occurred while fetching URL Preview Metadata!', error: ex, trace: stack);
    }

    // If the everything in the metadata is null or empty, try to manually parse
    if (data?.toMap().values.where((e) => !isNullOrEmpty(e)).isEmpty ?? true) {
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

  /// Resolves [imageUrl] to a local disk-cached file path shared across
  /// messages (content-addressed by MD5 hash, see [FilesystemService.saveUrlPreviewImage]).
  /// If [message.metadata]`[metadataKey]` already points to a file on disk, that
  /// path is returned immediately with `fromDisk: true`. Otherwise the image is
  /// downloaded via [HttpSvc], cached to disk, and the resulting hash is
  /// persisted back onto [message.metadata]. Returns `null` on failure.
  static Future<(String path, bool fromDisk)?> resolveCachedImage(
    Message message,
    String metadataKey,
    String imageUrl,
  ) async {
    if (kIsWeb) return null;

    final storedMd5 = message.metadata?[metadataKey] as String?;
    if (storedMd5 != null) {
      final cachedPath = FilesystemSvc.urlPreviewImagePath(storedMd5);
      if (await File(cachedPath).exists()) {
        return (cachedPath, true);
      }
    }

    try {
      final response = await HttpSvc.dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes, followRedirects: true, maxRedirects: 10),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final hash = await FilesystemSvc.saveUrlPreviewImage(Uint8List.fromList(bytes));
      message.metadata = {...?message.metadata, metadataKey: hash};
      if (message.id != null) message.save();
      return (FilesystemSvc.urlPreviewImagePath(hash), false);
    } catch (ex, stack) {
      Logger.warn('Failed to cache preview image', error: ex, trace: stack, tag: 'MetadataHelper');
      return null;
    }
  }

  static Future<Metadata> getLocationMetadata(Position locationData) async {
    String metaUrl =
        "https://maps.apple.com/?ll=${locationData.latitude},${locationData.longitude}&q=${locationData.latitude},${locationData.longitude}";
    String userAgent =
        " Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0";

    HttpClient client = HttpClient();
    client.userAgent = userAgent;

    HttpClientRequest request = await client.getUrl(Uri.parse(metaUrl));
    HttpClientResponse response = await request.close();
    String data = await response.transform(utf8.decoder).join();

    html.Document document = parser.parse(data);
    Metadata metadata = MetadataParser.parse(document);
    String title = document.getElementsByTagName("title")[0].text;
    int split = title.lastIndexOf(' - ');
    if (split != -1) {
      title = title.substring(0, split);
    }
    metadata.title = title;

    return metadata;
  }

  /// Manually tries to parse out metadata from a given [url]
  static Future<Metadata> _manuallyGetMetadata(String url) async {
    Metadata meta = Metadata();

    try {
      final response = await HttpSvc.dio.get(url,
          options: Options(
            followRedirects: true,
            maxRedirects: 2,
            headers: {
              // pretend to be a social media crawler
              "User-Agent":
                  "Mozilla/5.0 (Windows NT 6.1; rv:6.0) Gecko/20110814 Firefox/6.0 Google (+https://developers.google.com/+/web/snippet/)"
            },
          ));
      if (response.headers.value('content-type')?.startsWith("image/") ?? false) {
        meta.image = url;
      }
      final document = parser.parse(response.data);
      final props = document.head?.children
              .where((e) => e.localName == "meta" && e.attributes["property"].toString().contains("og:"))
              .map((e) => MapEntry(e.attributes["property"], e.attributes["content"]))
              .toList() ??
          [];
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
    } catch (ex, stack) {
      meta.title = ex.toString();
      Logger.error('Failed to manually get metadata!', error: ex, trace: stack);
    }

    return meta;
  }
}
