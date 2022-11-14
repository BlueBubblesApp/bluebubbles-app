import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

class UrlPreview extends StatefulWidget {
  final UrlPreviewData data;
  final Message message;

  UrlPreview({
    Key? key,
    required this.data,
    required this.message,
  }) : super(key: key);

  @override
  _UrlPreviewState createState() => _UrlPreviewState();
}

class _UrlPreviewState extends OptimizedState<UrlPreview> with AutomaticKeepAliveClientMixin {
  UrlPreviewData get data => widget.data;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    updateObx(() {
      if (data.imageMetadata?.url == null && data.iconMetadata?.url == null) {
        MetadataFetch.extract((data.url ?? data.originalUrl)!).then((metadata) {
          if (metadata?.image != null) {
            data.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata!.image);
            widget.message.save();
            setState(() {});
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final siteText = Uri.tryParse(data.url ?? data.originalUrl ?? "")?.host ?? data.siteName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.imageMetadata?.url != null && data.imageMetadata?.size != Size.zero)
          Image.network(
            data.imageMetadata!.url!,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, __, ___) {
              return const SizedBox.shrink();
            },
          ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title ?? "Unknown Site",
                      style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isNullOrEmpty(data.summary)!)
                      const SizedBox(height: 5),
                    if (!isNullOrEmpty(data.summary)!)
                      Text(
                        data.summary ?? "",
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)
                      ),
                    if (!isNullOrEmpty(siteText)!)
                      const SizedBox(height: 5),
                    if (!isNullOrEmpty(siteText)!)
                      Text(
                        siteText!,
                        style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                  ]
                ),
              ),
              const SizedBox(width: 10),
              if (data.iconMetadata?.url != null && data.imageMetadata?.size == Size.zero)
                Image.network(
                  data.iconMetadata!.url!,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.none,
                ),
            ],
          ),
        )
      ],
    );
  }
}
