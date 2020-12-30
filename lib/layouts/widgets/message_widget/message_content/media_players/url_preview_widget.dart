import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;

class UrlPreviewWidget extends StatefulWidget {
  UrlPreviewWidget(
      {Key key, @required this.linkPreviews, @required this.message})
      : super(key: key);
  final List<Attachment> linkPreviews;
  final Message message;

  @override
  _UrlPreviewWidgetState createState() => _UrlPreviewWidgetState();
}

class _UrlPreviewWidgetState extends State<UrlPreviewWidget>
    with TickerProviderStateMixin {
  Metadata data;
  bool currentIsLoading = false;
  StreamController<bool> loadingStateStream =
      StreamController<bool>.broadcast();

  bool get isLoading => currentIsLoading;
  set isLoading(bool value) {
    if (currentIsLoading == value) return;

    currentIsLoading = value;
    if (!loadingStateStream.isClosed)
      loadingStateStream.sink.add(currentIsLoading);
  }

  bool fetchedMissing = false;

  @override
  void initState() {
    super.initState();
    fetchPreview();
  }

  @override
  void dispose() {
    loadingStateStream.close();
    super.dispose();
  }

  /// Returns a File object representing the [attachment]
  File attachmentFile(Attachment attachment) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName =
        "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    return new File(pathName);
  }

  void fetchMissingAttachments() {
    // We only want to try fetching once
    if (fetchedMissing) return;

    for (Attachment attachment in widget.linkPreviews) {
      if (AttachmentHelper.attachmentExists(attachment)) continue;
      AttachmentDownloader(attachment, onComplete: () {
        if (this.mounted) setState(() {});
      });
    }

    if (widget.linkPreviews.length > 0) {
      fetchedMissing = true;
    }
  }

  /// Manually tries to parse out metadata from a given [url]
  Future<Metadata> manuallyGetMetadata(String url) async {
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

  String reformatUrl(String url) {
    if (url.contains('youtube.com/watch?v=') || url.contains("youtu.be/")) {
      return "https://www.youtube.com/oembed?url=$url";
    } else if (url.contains("twitter.com") && url.contains("/status/")) {
      return "https://publish.twitter.com/oembed?url=$url";
    } else {
      return url;
    }
  }

  Future<void> fetchPreview() async {
    // Try to get any already loaded attachment data
    if (CurrentChat.of(context).urlPreviews?.containsKey(widget.message.text) !=
        null) {
      data = CurrentChat.of(context).urlPreviews[widget.message.text];
    }

    if (data != null || isEmptyString(widget.message.text) || isLoading) return;

    // Let the UI know we are loading
    isLoading = true;

    // Make sure there is a schema with the URL
    String url = widget.message.text;
    if (!widget.message.text.toLowerCase().startsWith("http://") &&
        !widget.message.text.toLowerCase().startsWith("https://")) {
      url = "https://" + widget.message.text;
    }

    String newUrl = reformatUrl(url);

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
        data = await this.manuallyGetMetadata(href);
        alreadyManual = true;
      }
    } else if (url.contains("linkedin.com/posts/")) {
      data = await this.manuallyGetMetadata(url);
      data.url = url;
      alreadyManual = true;
    } else {
      data = await extract(url);
    }

    // If the data or title was null, try to manually parse
    if (!alreadyManual && isNullOrEmpty(data?.title)) {
      data = await this.manuallyGetMetadata(url);
      data.url = url;
    }

    String imageData = data?.image ?? "";
    if (imageData.contains("renderTimingPixel.png") ||
        imageData.contains("fls-na.amazon.com")) {
      data?.image = null;
    }

    // Save the metadata
    if (context != null) {
      CurrentChat.of(context).urlPreviews[widget.message.text] = data;
    }

    // We are done loading
    isLoading = false;
    bool didSetState = false;

    // Only update the state if we have more information
    if (data?.title != null ||
        data?.description != null ||
        (widget.linkPreviews.length <= 1 && data?.image != null)) {
      if (this.mounted) {
        didSetState = true;
        setState(() {});
      }
    }

    // If we never updated the state due to the preview metadata change,
    // Update the state because of the isLoading toggle
    if (!didSetState && this.mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget titleWidget = StreamBuilder(
      stream: loadingStateStream.stream,
      builder: (context, snapshot) {
        if (data == null && isLoading) {
          return Text("Loading Preview...",
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .apply(fontWeightDelta: 2));
        } else if (data != null && data.title != null) {
          return Text(
            data.title,
            style:
                Theme.of(context).textTheme.bodyText1.apply(fontWeightDelta: 2),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          );
        } else {
          return Text("Unable to Load Preview",
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .apply(fontWeightDelta: 2));
        }
      },
    );

    // Everytime we build, we want to fetch any missing attachments
    fetchMissingAttachments();

    // Build the main image
    Widget mainImage = Container();
    if (widget.linkPreviews.length <= 1 &&
        data?.image != null &&
        data.image.isNotEmpty) {
      mainImage = Image.network(data.image,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => Container());
    } else if (widget.linkPreviews.length > 1 &&
        AttachmentHelper.attachmentExists(widget.linkPreviews.last)) {
      mainImage = Image.file(attachmentFile(widget.linkPreviews.last),
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => Container());
    }

    return AnimatedSize(
      curve: Curves.easeInOut,
      alignment: Alignment.center,
      duration: Duration(milliseconds: 500),
      vsync: this,
      child: Padding(
        padding: EdgeInsets.only(
          top: widget.message.hasReactions ? 18.0 : 4,
          bottom: 4,
          right: !widget.message.isFromMe && widget.message.hasReactions
              ? 10.0
              : 5.0,
          left:
              widget.message.isFromMe && widget.message.hasReactions ? 5.0 : 0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Theme.of(context).accentColor,
            child: InkResponse(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                MethodChannelInterface().invokeMethod(
                  "open-link",
                  {"link": data?.url ?? widget.message.text},
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 2 / 3,
                child: Column(
                  children: <Widget>[
                    mainImage,
                    Padding(
                      padding:
                          EdgeInsets.only(left: 14.0, right: 14.0, top: 14.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Flexible(
                            fit: FlexFit.tight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                titleWidget,
                                data != null && data.description != null
                                    ? Padding(
                                        padding: EdgeInsets.only(top: 5.0),
                                        child: Text(
                                          data.description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1
                                              .apply(fontSizeDelta: -5),
                                        ))
                                    : Container(),
                                Padding(
                                  padding:
                                      EdgeInsets.only(top: 5.0, bottom: 10.0),
                                  child: Text(
                                    widget.message.text
                                        .replaceAll("https://", "")
                                        .replaceAll("http://", "")
                                        .toLowerCase(),
                                    style:
                                        Theme.of(context).textTheme.subtitle2,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          (widget.linkPreviews.length == 1 &&
                                  data?.image == null &&
                                  AttachmentHelper.attachmentExists(
                                      widget.linkPreviews.last))
                              ? Padding(
                                  padding:
                                      EdgeInsets.only(left: 10.0, bottom: 10.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10.0),
                                    child: Image.file(
                                      attachmentFile(widget.linkPreviews.first),
                                      width: 40,
                                      fit: BoxFit.contain,
                                      errorBuilder: (BuildContext contenxt,
                                          Object test, StackTrace trace) {
                                        return Container();
                                      },
                                    ),
                                  ),
                                )
                              : Container()
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
