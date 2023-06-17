import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:url_launcher/url_launcher.dart';

class LegacyUrlPreview extends StatefulWidget {
  final Message message;

  LegacyUrlPreview({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  OptimizedState createState() => _LegacyUrlPreviewState();
}

class _LegacyUrlPreviewState extends OptimizedState<LegacyUrlPreview> with AutomaticKeepAliveClientMixin {
  Message get message => widget.message;

  late Metadata? metadata = MetadataHelper.mapIsNotEmpty(message.metadata) ? Metadata.fromJson(message.metadata!) : null;

  @override
  void initState() {
    super.initState();
    updateObx(() async {
      if (metadata == null) {
        try {
          metadata = await MetadataHelper.fetchMetadata(message);
        } catch (ex) {
          Logger.error("Failed to fetch metadata! Error: ${ex.toString()}");
          return;
        }
        // If the data isn't empty, save/update it in the DB
        if (MetadataHelper.isNotEmpty(metadata)) {
          message.updateMetadata(metadata);
        }
        setState(() {});
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final siteText = Uri.tryParse(metadata?.url ?? message.text ?? "")?.host;
    return InkWell(
      onTap: () async {
        if ((metadata?.url ?? message.text) != null) {
          await launchUrl(
            Uri.parse((metadata?.url ?? message.text)!),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metadata?.image != null && ReplyScope.maybeOf(context) == null)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(metadata!.image!),
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
                        metadata!.image!,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (context, object, stacktrace) => const SizedBox.shrink(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !isNullOrEmpty(metadata?.title)!
                      ? metadata!.title!
                      : !isNullOrEmpty(siteText)!
                      ? siteText! : message.text!,
                  style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isNullOrEmpty(metadata?.description)!)
                  const SizedBox(height: 5),
                if (!isNullOrEmpty(metadata?.description)!)
                  Text(
                    metadata!.description!,
                    maxLines: ReplyScope.maybeOf(context) == null ? 3 : 1,
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
          )
        ],
      ),
    );
  }
}
