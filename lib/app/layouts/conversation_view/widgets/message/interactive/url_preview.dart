import 'dart:convert';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' as parser;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlPreview extends StatefulWidget {
  final UrlPreviewData data;
  final Message message;
  final PlatformFile? file;

  UrlPreview({
    super.key,
    required this.data,
    required this.message,
    this.file,
  });

  @override
  OptimizedState createState() => _UrlPreviewState();
}

class _UrlPreviewState extends OptimizedState<UrlPreview> with AutomaticKeepAliveClientMixin {
  UrlPreviewData get data => widget.data;
  UrlPreviewData? dataOverride;
  dynamic get file => File(content.path!);
  dynamic content;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    updateObx(() async {
      // refers to a location widget
      if (widget.file != null) {
        String? _location;
        if (kIsWeb || widget.file!.path == null) {
          _location = utf8.decode(widget.file!.bytes!);
        } else {
          _location = await File(widget.file!.path!).readAsString();
        }
        dataOverride = UrlPreviewData(
          title: data.title,
          siteName: data.siteName,
        );
        dataOverride!.url = as.parseAppleLocationUrl(_location)?.replaceAll("\\", "").replaceAll("http:", "https:").replaceAll("/?", "/place?").replaceAll(",", "%2C");
        if (dataOverride!.url == null) return;
        final response = await http.dio.get(dataOverride!.url!);
        final document = parser.parse(response.data);
        final link = document.getElementsByClassName("sc-platter-cell").firstOrNull?.children.firstWhereOrNull((e) => e.localName == "a");
        final url = link?.attributes["href"];
        if (url != null) {
          MetadataFetch.extract(dataOverride!.url!).then((metadata) {
            if (metadata?.image != null) {
              dataOverride!.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata!.image);
              dataOverride!.summary = metadata.description ?? metadata.title;
              dataOverride!.url = url;
              setState(() {});
            }
          });
        }
      } else if (data.imageMetadata?.url == null && data.iconMetadata?.url == null) {
        final attachment = widget.message.attachments
            .firstWhereOrNull((e) => e?.transferName?.contains("pluginPayloadAttachment") ?? false);
        if (attachment != null) {
          content = as.getContent(attachment, autoDownload: true, onComplete: (file) {
            setState(() {
              content = file;
            });
          });
          if (content is PlatformFile) {
            setState(() {});
          }
        } else {
          MetadataFetch.extract((data.url ?? data.originalUrl)!).then((metadata) async {
            if (metadata?.image != null) {
              data.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata!.image);
              widget.message.save();
              setState(() {});
            } else {
              final response = await http.dio.get((data.url ?? data.originalUrl)!);
              if (response.headers.value('content-type')?.startsWith("image/") ?? false) {
                data.imageMetadata = MediaMetadata(size: const Size.square(1), url: (data.url ?? data.originalUrl)!);
                widget.message.save();
                setState(() {});
              }
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final siteText = widget.file != null ? (dataOverride?.siteName ?? "") : Uri.tryParse(data.url ?? data.originalUrl ?? "")?.host ?? data.siteName;
    final hasAppleImage = (data.imageMetadata?.url == null || (data.iconMetadata?.url == null && data.imageMetadata?.size == Size.zero));
    final _data = dataOverride ?? data;
    return InkWell(
      onTap: widget.file != null && _data.url != null ? () async {
        await launchUrl(
          Uri.parse(_data.url!),
          mode: LaunchMode.externalApplication
        );
      } : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_data.imageMetadata?.url != null && ReplyScope.maybeOf(context) == null)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(_data.imageMetadata!.url!),
                  fit: BoxFit.cover,
                ),
              ),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: context.height * 0.4),
                      child: Image.network(
                        _data.imageMetadata!.url!,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (context, object, stacktrace) => Center(
                          heightFactor: 1,
                          child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (content is PlatformFile && hasAppleImage && content.bytes != null && ReplyScope.maybeOf(context) == null)
           Container(
             decoration: BoxDecoration(
               image: DecorationImage(
                 image: MemoryImage(content.bytes!),
                 fit: BoxFit.cover,
               ),
             ),
             child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: context.height * 0.4),
                    child: Image.memory(
                      content.bytes!,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, object, stacktrace) => Center(
                        heightFactor: 1,
                        child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                      ),
                    ),
                  ),
                ),
              ),
           ),
          if (content is PlatformFile && hasAppleImage && content.bytes == null && content.path != null && ReplyScope.maybeOf(context) == null)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(file),
                  fit: BoxFit.cover,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: context.height * 0.4),
                    child: Image.file(
                      file,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, object, stacktrace) => Center(
                        heightFactor: 1,
                        child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !isNullOrEmpty(_data.title)
                            ? _data.title!
                            : !isNullOrEmpty(siteText)
                            ? siteText! : widget.message.text!,
                        style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isNullOrEmpty(_data.summary))
                        const SizedBox(height: 5),
                      if (!isNullOrEmpty(_data.summary))
                        Text(
                          _data.summary ?? "",
                          maxLines: ReplyScope.maybeOf(context) == null ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)
                        ),
                      if (!isNullOrEmpty(siteText))
                        const SizedBox(height: 5),
                      if (!isNullOrEmpty(siteText))
                        Text(
                          siteText!,
                          style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                        ),
                    ]
                  ),
                ),
                if (_data.iconMetadata?.url != null)
                  const SizedBox(width: 10),
                if (_data.iconMetadata?.url != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 45,
                    ),
                    child: Image.network(
                      _data.iconMetadata!.url!,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
