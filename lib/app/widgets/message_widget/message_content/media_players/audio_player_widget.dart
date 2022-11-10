import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_lifecycle_manager.dart';
import 'package:bluebubbles/models/global/platform_file.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

class AudioPlayerWidget extends StatefulWidget {
  AudioPlayerWidget({
    Key? key,
    required this.file,
    required this.context,
    this.isFromMe = false,
    this.width,
  }) : super(key: key);

  final PlatformFile file;
  final BuildContext context;
  final double? width;
  final bool isFromMe;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final ChewieAudioController controller;
  late final VideoPlayerController audioController;

  @override
  void initState() {
    super.initState();

    ConversationViewController thisChat = cvc(cm.activeChat!.chat);
    if (!kIsWeb && thisChat.audioPlayers.containsKey(widget.file.path)) {
      audioController = thisChat.audioPlayers[widget.file.path]!.item2;
      controller = thisChat.audioPlayers[widget.file.path]!.item1;
    } else {
      if (kIsWeb || widget.file.path == null) {
        final blob = html.Blob([widget.file.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        audioController = VideoPlayerController.network(url);
      } else {
        dynamic file = File(widget.file.path!);
        audioController = VideoPlayerController.file(file);
      }
      controller = ChewieAudioController(
        videoPlayerController: audioController,
        autoPlay: false,
        looping: false,
        showSeekButtons: false,
        showControls: true,
        autoInitialize: true,
        materialProgressColors: ChewieProgressColors(
            playedColor: Get.context!.theme.colorScheme.primary,
            handleColor: Get.context!.theme.colorScheme.primary,
            bufferedColor: Get.context!.theme.colorScheme.primaryContainer,
            backgroundColor: Get.context!.theme.colorScheme.properSurface),
        cupertinoProgressColors: ChewieProgressColors(
            playedColor: Get.context!.theme.colorScheme.primary,
            handleColor: Get.context!.theme.colorScheme.primary,
            bufferedColor: Get.context!.theme.colorScheme.primaryContainer,
            backgroundColor: Get.context!.theme.colorScheme.properSurface),
        cupertinoBackgroundColor: Get.context!.theme.colorScheme.properSurface,
        cupertinoIconColor: Get.context!.theme.colorScheme.properOnSurface,
        cupertinoColumnAlignment: widget.isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      );

      if (!kIsWeb && widget.file.path != null) {
        thisChat.audioPlayers[widget.file.path!] = Tuple2(controller, audioController);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString();
    int sec = (duration.inSeconds - (duration.inMinutes * 60));
    String seconds = sec.isNaN || sec.isNegative ? "0" : sec.toString();
    minutes = (minutes.length == 1) ? "0$minutes" : minutes;
    seconds = (seconds.length == 1) ? "0$seconds" : seconds;
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    double maxWidth = widget.width ?? ns.width(context) - 20;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      controller.pause();
    }
    return Container(
      alignment: Alignment.center,
      color: context.theme.colorScheme.properSurface,
      height: ss.settings.skin.value == Skins.iOS && !kIsWeb && !kIsDesktop ? 75 : 48,
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Theme(
        data: context.theme.copyWith(
            platform: ss.settings.skin.value == Skins.iOS && !kIsWeb && !kIsDesktop ? TargetPlatform.iOS : TargetPlatform.android,
            dialogBackgroundColor: context.theme.colorScheme.properSurface,
            iconTheme: context.theme.iconTheme.copyWith(color: context.theme.colorScheme.properOnSurface)),
        child: ChewieAudio(
          controller: controller,
        ),
      ),
    );
  }
}