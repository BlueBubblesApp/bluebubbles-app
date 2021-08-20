import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

class UrlPreviewWidget extends StatefulWidget {
  UrlPreviewWidget({Key? key, required this.linkPreviews, required this.message}) : super(key: key);
  final List<Attachment?> linkPreviews;
  final Message message;

  @override
  _UrlPreviewWidgetState createState() => _UrlPreviewWidgetState();
}

class _UrlPreviewWidgetState extends State<UrlPreviewWidget> with TickerProviderStateMixin {
  Metadata? data;
  bool currentIsLoading = false;
  StreamController<bool> loadingStateStream = StreamController<bool>.broadcast();

  bool get isLoading => currentIsLoading;

  set isLoading(bool value) {
    if (currentIsLoading == value) return;

    currentIsLoading = value;
    if (!loadingStateStream.isClosed) loadingStateStream.sink.add(currentIsLoading);
  }

  bool fetchedMissing = false;

  @override
  void initState() {
    super.initState();

    // If we already have metadata, don't re-fetch it
    if (MetadataHelper.mapIsNotEmpty(widget.message.metadata)) {
      data = Metadata.fromJson(widget.message.metadata!);
    } else {
      fetchPreview();
    }
  }

  @override
  void dispose() {
    loadingStateStream.close();
    super.dispose();
  }

  /// Returns a File object representing the [attachment]
  File attachmentFile(Attachment attachment) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    return new File(pathName);
  }

  void fetchMissingAttachments() {
    // We only want to try fetching once
    if (fetchedMissing) return;

    for (Attachment? attachment in widget.linkPreviews) {
      if (AttachmentHelper.attachmentExists(attachment!)) continue;
      Get.put(AttachmentDownloadController(attachment: attachment, onComplete: () {
        if (this.mounted) setState(() {});
      }), tag: attachment.guid);
    }

    if (widget.linkPreviews.length > 0) {
      fetchedMissing = true;
    }
  }

  Future<void> fetchPreview() async {
    // Try to get any already loaded attachment data
    if (CurrentChat.of(context)!.urlPreviews.containsKey(widget.message.text)) {
      data = CurrentChat.of(context)!.urlPreviews[widget.message.text];
    }

    if (data != null || isLoading) return;

    // Let the UI know we are loading
    isLoading = true;

    Metadata? meta;

    try {
      // Fetch the metadata
      meta = await MetadataHelper.fetchMetadata(widget.message);
    } catch (ex) {
      debugPrint("Failed to fetch metadata! Error: ${ex.toString()}");
      isLoading = false;
      if (this.mounted) {
        setState(() {});
      }

      return;
    }

    // If the data isn't empty, save/update it in the DB
    if (MetadataHelper.isNotEmpty(meta)) {
      // If pre-caching is enabled, fetch the image and save it
      if (SettingsManager().settings.preCachePreviewImages.value && !isNullOrEmpty(meta!.image)!) {
        // Save from URL
        File? newFile = await saveImageFromUrl(widget.message.guid!, meta.image!);

        // If we downloaded a file, set the new metadata path
        if (newFile != null && newFile.existsSync()) {
          meta.image = newFile.path;
        }
      }

      widget.message.updateMetadata(meta);

      if (!MetadataHelper.isNotEmpty(data)) {
        data = meta;
      }
    }

    // Save the metadata
    if (data != null) {
      CurrentChat.of(context)!.urlPreviews[widget.message.text!] = data!;
    }

    // We are done loading
    isLoading = false;
    bool didSetState = false;

    // Only update the state if we have more information
    if (MetadataHelper.isNotEmpty(meta) && widget.linkPreviews.length <= 1) {
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
          return Text("Loading Preview...", style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2));
        } else if (data != null && data!.title != null && data!.title != "Image Preview") {
          return Text(
            data?.title ?? "<No Title>",
            style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          );
        } else if (data?.title == "Image Preview") {
          return Container();
        } else {
          return Text("Unable to Load Preview",
              style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2));
        }
      },
    );

    // Everytime we build, we want to fetch any missing attachments
    fetchMissingAttachments();

    // Build the main image
    Widget mainImage = Container();
    if (widget.linkPreviews.length <= 1 && data?.image != null && data!.image!.isNotEmpty) {
      if (data!.image!.startsWith("/")) {
        mainImage = Image.file(new File(data!.image!),
            filterQuality: FilterQuality.low, errorBuilder: (context, error, stackTrace) => Container());
      } else {
        mainImage = Image.network(data!.image!,
            filterQuality: FilterQuality.low, errorBuilder: (context, error, stackTrace) => Container());
      }
    } else if (widget.linkPreviews.length > 1 && AttachmentHelper.attachmentExists(widget.linkPreviews.last!)) {
      mainImage = Image.file(attachmentFile(widget.linkPreviews.last!),
          filterQuality: FilterQuality.low, errorBuilder: (context, error, stackTrace) => Container());
    }

    final bool hideContent = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideMessageContent.value;
    final bool hideType = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;

    List<Widget> items = [
      mainImage,
      Padding(
        padding: EdgeInsets.only(left: 14.0, right: 14.0, top: 14.0),
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
                  data != null && data!.description != null
                      ? Padding(
                          padding: EdgeInsets.only(top: 5.0),
                          child: Text(
                            data!.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeDelta: -5),
                          ))
                      : Container(),
                  Padding(
                    padding: EdgeInsets.only(top: (data?.title == "Image Preview" ? 0 : 5.0), bottom: 10.0),
                    child: Text(
                      widget.message.text!.replaceAll("https://", "").replaceAll("http://", "").toLowerCase(),
                      style: Theme.of(context).textTheme.subtitle2,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            (widget.linkPreviews.length == 1 &&
                    data?.image == null &&
                    AttachmentHelper.attachmentExists(widget.linkPreviews.last!))
                ? Padding(
                    padding: EdgeInsets.only(left: 10.0, bottom: 10.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Image.file(
                        attachmentFile(widget.linkPreviews.first!),
                        width: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext contenxt, Object test, StackTrace? trace) {
                          return Container();
                        },
                      ),
                    ),
                  )
                : Container()
          ],
        ),
      ),
      if (hideContent)
        Positioned.fill(
          child: Container(
            color: Theme.of(context).accentColor,
          ),
        ),
      if (hideContent && !hideType)
        Positioned.fill(
            child: Container(
                alignment: Alignment.center,
                child: Text(
                  "link",
                  textAlign: TextAlign.center,
                )))
    ];

    return AnimatedSize(
      curve: Curves.easeInOut,
      alignment: Alignment.center,
      duration: Duration(milliseconds: 200),
      vsync: this,
      child: Padding(
        padding: EdgeInsets.only(
          top: widget.message.hasReactions ? 18.0 : 4,
          bottom: 4,
          right: !widget.message.isFromMe! && widget.message.hasReactions ? 10.0 : 5.0,
          left: widget.message.isFromMe! && widget.message.hasReactions ? 5.0 : 0,
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
                  {"link": data?.url ?? widget.message.text, "forceBrowser": false},
                );
              },
              child: Container(
                // The minus 5 here is so the timestamps show OK during swipe
                width: (context.width * 2 / 3) - 5,
                child: (hideContent || hideType) ? Stack(children: items) : Column(children: items),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
