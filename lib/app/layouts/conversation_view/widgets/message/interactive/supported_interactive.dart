import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class SupportedInteractive extends StatefulWidget {
  final iMessageAppData data;
  final Message message;

  SupportedInteractive({
    super.key,
    required this.data,
    required this.message,
  });

  @override
  OptimizedState createState() => _SupportedInteractiveState();
}

class _SupportedInteractiveState extends OptimizedState<SupportedInteractive> with AutomaticKeepAliveClientMixin {
  iMessageAppData get data => widget.data;
  dynamic get file => File(content.path!);
  dynamic content;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    updateObx(() async {
      final attachment = widget.message.attachments.firstOrNull;
      if (attachment != null) {
        content = as.getContent(attachment, autoDownload: true, onComplete: (file) {
          setState(() {
            content = file;
          });
        });
        if (content is PlatformFile) {
          setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.bottomLeft,
          children: [
            if (content is PlatformFile && content.bytes != null)
              Image.memory(
                content.bytes!,
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, object, stacktrace) => Center(
                  heightFactor: 1,
                  child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                ),
              ),
            if (content is PlatformFile && content.bytes == null && content.path != null)
              Image.file(
                file,
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, object, stacktrace) => Center(
                  heightFactor: 1,
                  child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                ),
              ),
            if (!isNullOrEmpty(data.userInfo?.imageTitle) || !isNullOrEmpty(data.userInfo?.imageSubtitle))
              Positioned(
                bottom: 5,
                left: 15,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isNullOrEmpty(data.userInfo?.imageTitle))
                      Text(
                        data.userInfo!.imageTitle!,
                        style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!isNullOrEmpty(data.userInfo?.imageSubtitle))
                      Text(
                        data.userInfo!.imageSubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)
                      ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isNullOrEmpty(data.userInfo?.caption))
                    Flexible(
                      fit: !isNullOrEmpty(data.userInfo?.secondarySubcaption) ? FlexFit.tight : FlexFit.loose,
                      child: Text(
                        data.userInfo!.caption!,
                        style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (isNullOrEmpty(data.userInfo?.caption) && !isNullOrEmpty(data.ldText))
                    Flexible(
                      fit: !isNullOrEmpty(data.userInfo?.secondarySubcaption) ? FlexFit.tight : FlexFit.loose,
                      child: Text(
                        data.ldText!,
                        style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (!isNullOrEmpty(data.userInfo?.secondarySubcaption))
                    Text(
                      data.userInfo!.secondarySubcaption!,
                      style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              if (!isNullOrEmpty(data.userInfo?.subcaption))
                const SizedBox(height: 2.5),
              if (!isNullOrEmpty(data.userInfo?.subcaption))
                Text(
                  data.userInfo!.subcaption!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)
                ),
              if (!isNullOrEmpty(data.appName))
                const SizedBox(height: 5),
              if (!isNullOrEmpty(data.appName))
                Text(
                  data.appName!,
                  style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
            ]
          ),
        )
      ],
    );
  }
}
