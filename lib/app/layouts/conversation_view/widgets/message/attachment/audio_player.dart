import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
// it does actually export (Web only)
// ignore: undefined_hidden_name
import 'package:bluebubbles/models/models.dart' hide PlayerState;
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AudioPlayer extends StatefulWidget {
  final PlatformFile file;
  final Attachment? attachment;

  AudioPlayer({
    Key? key,
    required this.file,
    required this.attachment,
    this.controller,
  }) : super(key: key);

  final ConversationViewController? controller;

  @override
  OptimizedState createState() => kIsDesktop ? _DesktopAudioPlayerState() : _AudioPlayerState();
}

class _AudioPlayerState extends OptimizedState<AudioPlayer> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  Attachment? get attachment => widget.attachment;

  PlatformFile get file => widget.file;

  ConversationViewController? get cvController => widget.controller;

  PlayerController? controller;
  late final animController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400), animationBehavior: AnimationBehavior.preserve);

  @override
  void initState() {
    super.initState();
    if (attachment != null) controller = cvController?.audioPlayers[attachment!.guid];
    updateObx(() {
      initBytes();
    });
  }

  @override
  void dispose() {
    if (attachment == null) {
      controller?.dispose();
    }
    animController.dispose();
    super.dispose();
  }

  void initBytes() async {
    if (attachment != null) controller = cvController?.audioPlayers[attachment!.guid];
    if (controller == null) {
      controller = PlayerController()
        ..addListener(() {
          setState(() {});
        });
      controller!.onPlayerStateChanged.listen((event) {
        if ((controller!.playerState == PlayerState.paused || controller!.playerState == PlayerState.stopped) && animController.value > 0) {
          animController.reverse();
        }
        setState(() {});
      });
      await controller!.preparePlayer(path: file.path!);
      if (attachment != null) cvController?.audioPlayers[attachment!.guid!] = controller!;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            IconButton(
              onPressed: () async {
                if (controller == null) return;
                if (controller!.playerState == PlayerState.playing) {
                  animController.reverse();
                  await controller!.pausePlayer();
                } else {
                  animController.forward();
                  await controller!.startPlayer(finishMode: FinishMode.pause);
                }
                setState(() {});
              },
              icon: AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: animController,
              ),
              color: context.theme.colorScheme.properOnSurface,
              visualDensity: VisualDensity.compact,
            ),
            (controller?.maxDuration ?? 0) == 0
                ? SizedBox(width: ns.width(context) * 0.25)
                : AudioFileWaveforms(
                    size: Size(ns.width(context) * 0.25, 40),
                    playerController: controller!,
                    padding: EdgeInsets.zero,
                    playerWaveStyle: PlayerWaveStyle(
                        fixedWaveColor: context.theme.colorScheme.properSurface.oppositeLightenOrDarken(20),
                        liveWaveColor: context.theme.colorScheme.properOnSurface,
                        waveCap: StrokeCap.square,
                        waveThickness: 2,
                        seekLineThickness: 2,
                        showSeekLine: false),
                  ),
            const SizedBox(width: 5),
            Expanded(
              child: Center(
                heightFactor: 1,
                child: Text(prettyDuration(Duration(milliseconds: controller?.maxDuration ?? 0)), style: context.theme.textTheme.labelLarge!),
              ),
            ),
          ],
        ));
  }

  @override
  bool get wantKeepAlive => true;
}

class _DesktopAudioPlayerState extends OptimizedState<AudioPlayer> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  Attachment? get attachment => widget.attachment;

  PlatformFile get file => widget.file;

  ConversationViewController? get cvController => widget.controller;

  Player? controller;
  late final animController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400), animationBehavior: AnimationBehavior.preserve);

  @override
  void initState() {
    super.initState();
    if (attachment != null) controller = cvController?.audioPlayersDesktop[attachment!.guid];
    updateObx(() {
      initBytes();
    });
  }

  @override
  void dispose() {
    if (attachment == null) {
      controller?.dispose();
    }
    animController.dispose();
    super.dispose();
  }

  void initBytes() async {
    if (attachment != null) controller = cvController?.audioPlayersDesktop[attachment!.guid];
    if (controller == null) {
      controller = Player()..stream.position.listen((position) => setState(() {}))
      ..stream.completed.listen((bool completed) async {
        if (completed) {
          await controller!.pause();
          await controller!.seek(Duration.zero);
          animController.reverse();
        }
        setState(() {});
      });
      await controller!.setPlaylistMode(PlaylistMode.none);
      await controller!.open(Media(file.path!), play: false);
      if (attachment != null) cvController?.audioPlayersDesktop[attachment!.guid!] = controller!;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                if (controller == null) return;
                if (controller!.state.playing) {
                  animController.reverse();
                  await controller!.pause();
                } else {
                  animController.forward();
                  await controller!.play();
                }
                setState(() {});
              },
              icon: AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: animController,
              ),
              color: context.theme.colorScheme.properOnSurface,
              visualDensity: VisualDensity.compact,
            ),
            if (controller != null)
              SizedBox(
                height: 30,
                child: Slider(
                  value: controller!.state.position.inSeconds.toDouble(),
                  onChanged: (double value) {
                    controller!.seek(Duration(seconds: value.toInt()));
                  },
                  min: 0,
                  max: controller!.state.duration.inSeconds.toDouble(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 16),
              child: Text("${prettyDuration(controller?.state.position ?? Duration.zero)} / ${prettyDuration(controller?.state.duration ?? Duration.zero)}"),
            )
          ],
        ));
  }

  @override
  bool get wantKeepAlive => true;
}
