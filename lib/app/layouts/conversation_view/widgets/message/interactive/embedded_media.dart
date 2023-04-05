import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/video_player.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

class EmbeddedMedia extends CustomStateful<MessageWidgetController> {
  EmbeddedMedia({
    Key? key,
    required this.message,
    required super.parentController,
  }) : super(key: key);

  final Message message;

  @override
  State<EmbeddedMedia> createState() => _EmbeddedMediaState();
}

class _EmbeddedMediaState extends CustomState<EmbeddedMedia, void, MessageWidgetController> with AutomaticKeepAliveClientMixin {
  Message get message => widget.message;

  dynamic content;

  @override
  void initState() {
    super.initState();
    updateObx(() async {
      getContent();
    });
  }

  void getContent() async {
    final path = message.interactiveMediaPath!;
    if (await File(path).exists()) {
      final bytes = await File(path).readAsBytes();
      content = PlatformFile(
        name: path.split("/").last,
        path: path,
        size: bytes.length,
        bytes: bytes,
      );
      setState(() {});
    } else {
      content = Rx<Tuple2<int, int>>(const Tuple2(0, 0));
      setState(() {});
      http.embeddedMedia(message.guid!, onReceiveProgress: (current, total) {
        if (content is Rx) {
          (content as Rx<Tuple2<int, int>>).value = Tuple2(current, total);
        }
      }).then((response) async {
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(response.data);
        content = PlatformFile(
          name: path.split("/").last,
          path: path,
          size: response.data.length,
          bytes: response.data,
        );
        setState(() {});
      }).catchError((err) {
        content = "failed";
        setState(() {});
      });
    }
  }

  String getAppName() {
    final balloonBundleId = message.balloonBundleId;
    final temp = balloonBundleIdMap[balloonBundleId?.split(":").first];
    String? name;
    if (temp is Map) {
      name = temp[balloonBundleId?.split(":").last];
    } else if (temp is String) {
      name = temp;
    }
    return name ?? "Unknown";
  }

  @override
  void updateWidget(void _) {
    if (File(message.interactiveMediaPath!).existsSync()) {
      File(message.interactiveMediaPath!).deleteSync();
      content = null;
      super.updateWidget(_);
      getContent();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content is PlatformFile && content.bytes != null && content.name.endsWith(".png"))
          Image.memory(
            content.bytes!,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        if (content is PlatformFile && content.bytes != null && content.name.endsWith(".mov"))
          VideoPlayer(
            file: content,
            attachment: Attachment(
              guid: message.guid,
            ),
            controller: controller.cvController,
            isFromMe: message.isFromMe!,
          ),
        if (content is! PlatformFile)
          InkWell(
            onTap: content is String ? () {
              getContent();
            } : null,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getAppName(),
                            style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            content is Rx ? "Downloading media..." : "Failed to load media!",
                            style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                            overflow: TextOverflow.clip,
                            maxLines: 2,
                          ),
                        ]
                    ),
                  ),
                  if (content is Rx<Tuple2>)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: Center(
                        child: Obx(() => CircleProgressBar(
                          value: content.value.item2 > 0 ? content.value.item1 / content.value.item2 : 0,
                          backgroundColor: context.theme.colorScheme.outline,
                          foregroundColor: context.theme.colorScheme.properOnSurface,
                        )),
                      ),
                    ),
                  if (content is String)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: Center(
                        child: Icon(iOS ? CupertinoIcons.arrow_clockwise : Icons.refresh, size: 30),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
