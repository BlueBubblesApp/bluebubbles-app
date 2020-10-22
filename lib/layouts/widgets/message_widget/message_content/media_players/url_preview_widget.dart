import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;

class UrlPreviewWidget extends StatefulWidget {
  UrlPreviewWidget({
    Key key,
    @required this.linkPreviews,
    @required this.message,
    @required this.savedAttachmentData,
  }) : super(key: key);
  final List<Attachment> linkPreviews;
  final Message message;
  final SavedAttachmentData savedAttachmentData;

  @override
  _UrlPreviewWidgetState createState() => _UrlPreviewWidgetState();
}

class _UrlPreviewWidgetState extends State<UrlPreviewWidget>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  Metadata data;
  String url;

  @override
  void initState() {
    super.initState();
    if (widget.savedAttachmentData.urlMetaData != null)
      data = widget.savedAttachmentData
          .urlMetaData[widget.message.guid + "-url-preview"];
  }

  bool attachmentSaved(Attachment attachment) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName =
        "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    if (FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound) {
      return false;
    } else {
      return true;
    }
  }

  File attachmentFile(Attachment attachment) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName =
        "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    return File(pathName);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (data == null && !isEmptyString(widget.message.text)) {
      url = widget.message.text;

      if (!widget.message.text.toLowerCase().startsWith("http://") &&
          !widget.message.text.toLowerCase().startsWith("https://")) {
        url = "https://" + widget.message.text;
      }

      if (url.contains('youtube.com/watch?v=')) {
        // Manually request this URL
        String newUrl = "https://www.youtube.com/oembed?url=$url";
        var response = await http.get(newUrl);

        // Manually load it into a metadata object via JSON
        data = Metadata.fromJson(jsonDecode(response.body));

        // Set the URL to the original URL
        data.url = url;
      } else {
        data = await extract(url);
      }

      widget.savedAttachmentData
          .urlMetaData[widget.message.guid + "-url-preview"] = data;
      if (this.mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedSize(
      curve: Curves.easeInOut,
      alignment: Alignment.center,
      duration: Duration(milliseconds: 500),
      vsync: this,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Theme.of(context).accentColor,
            child: InkResponse(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                MethodChannelInterface()
                    .invokeMethod("open-link", {"link": url});
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 2 / 3,
                child: Column(
                  children: <Widget>[
                    widget.linkPreviews.length > 1
                        ? attachmentSaved(widget.linkPreviews.last)
                            ? Image.file(
                                attachmentFile(widget.linkPreviews.last),
                                filterQuality: FilterQuality.low,
                              )
                            : CupertinoActivityIndicator(
                                animating: true,
                              )
                        : Container(),
                    Padding(
                      padding: EdgeInsets.only(left: 14.0, right: 14.0, top: 14.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          data != null
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    data != null
                                        ? Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                4 /
                                                9,
                                            child: Text(
                                              data.title != null
                                                  ? data.title
                                                  : "Loading...",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText1
                                                  .apply(
                                                      fontWeightDelta: 2),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          )
                                        : Container(),
                                    data != null &&
                                            data.description != null
                                        ? Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                4 /
                                                9,
                                            child: Text(
                                              data.description,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText1
                                                  .apply(
                                                      fontSizeDelta: -5),
                                            ),
                                          )
                                        : Container(),
                                    Container(
                                      width: MediaQuery.of(context)
                                              .size
                                              .width *
                                          4 /
                                          9,
                                      child:Padding(
                                        padding: EdgeInsets.only(top: 5.0, bottom: 10.0),
                                        child: Text(
                                          widget.message.text,
                                          style: Theme.of(context)
                                              .textTheme
                                              .subtitle2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          maxLines: 1,
                                        )
                                      )
                                    )
                                  ],
                                )
                              : Container(),
                          attachmentSaved(widget.linkPreviews.first)
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(10.0),
                                  child: Image.file(
                                    attachmentFile(
                                        widget.linkPreviews.first),
                                    width: 40,
                                    fit: BoxFit.contain,
                                  ))
                              : CupertinoActivityIndicator(
                                  animating: true,
                                )
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

  @override
  bool get wantKeepAlive => true;
}
