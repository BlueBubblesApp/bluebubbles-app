import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/network/http_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

/// Mixin that provides live photo functionality for image viewers
/// Handles downloading, caching, and playback of live photos
mixin LivePhotoMixin<T extends StatefulWidget> on State<T> {
  // Live photo state - using GetX observables to minimize re-renders
  final RxBool isDownloadingLivePhoto = false.obs;
  final RxDouble livePhotoProgress = 0.0.obs;
  PlatformFile? livePhotoFile;
  Player? livePhotoPlayer;
  VideoController? livePhotoController;
  final RxBool isPlayingLivePhoto = false.obs;
  final RxDouble livePhotoOpacity = 0.0.obs;

  /// True once a [Video] texture is mounted (opacity may still be 0).
  /// Fullscreen pre-mounts this so hold-to-play does not create a platform view
  /// mid-gesture (Android cancels the active pointer when that happens).
  final RxBool isLivePhotoSurfaceReady = false.obs;

  /// Bumped on dispose and each new play so in-flight awaits no-op after teardown.
  int _livePhotoPlayGeneration = 0;
  int _livePhotoPrepareGeneration = 0;
  Timer? _livePhotoHideTimer;
  final List<StreamSubscription<dynamic>> _livePhotoSubscriptions = [];
  bool _livePhotoHideInProgress = false;

  /// True while a fullscreen press-and-hold session is active.
  bool _livePhotoHoldActive = false;

  /// When true, stop keeps the player/surface for the next hold.
  bool _livePhotoKeepSurface = false;

  static const Duration _livePhotoFadeDuration = Duration(milliseconds: 450);
  static const Duration _livePhotoFirstFrameGrace = Duration(milliseconds: 80);

  // Must be implemented by the using class
  Attachment get livePhotoAttachment;

  bool _isLivePhotoPlayActive(int generation) => mounted && generation == _livePhotoPlayGeneration;

  void _cancelLivePhotoAsyncWork() {
    _livePhotoHideTimer?.cancel();
    _livePhotoHideTimer = null;
    for (final sub in _livePhotoSubscriptions) {
      sub.cancel();
    }
    _livePhotoSubscriptions.clear();
  }

  Future<void> _disposeLivePhotoPlayer() async {
    final player = livePhotoPlayer;
    livePhotoPlayer = null;
    livePhotoController = null;
    isLivePhotoSurfaceReady.value = false;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {
      // Already disposed by a concurrent teardown.
    }
  }

  Future<void> _disposeOwnedPlayer(Player player) async {
    if (identical(livePhotoPlayer, player)) {
      await _disposeLivePhotoPlayer();
    } else {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  /// Mount [Video] at opacity 0, wait for a presentable first frame, then crossfade in.
  Future<void> _revealLivePhotoOverlay(int generation) async {
    if (!_isLivePhotoPlayActive(generation)) return;

    livePhotoOpacity.value = 0.0;
    isPlayingLivePhoto.value = true;
    isLivePhotoSurfaceReady.value = true;

    final controller = livePhotoController;
    if (controller == null) return;

    await controller.waitUntilFirstFrameRendered;
    if (!_isLivePhotoPlayActive(generation)) return;

    // media_kit completes waitUntilFirstFrameRendered on geometry, not surface present.
    await Future.delayed(_livePhotoFirstFrameGrace);
    if (!_isLivePhotoPlayActive(generation)) return;

    // Commit at least one opacity-0 frame so AnimatedOpacity tweens instead of jumping.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!_isLivePhotoPlayActive(generation)) return;

    livePhotoOpacity.value = 1.0;
  }

  Future<void> _hideLivePhotoOverlay(int generation) async {
    if (!_isLivePhotoPlayActive(generation) || !isPlayingLivePhoto.value || _livePhotoHideInProgress) {
      return;
    }
    _livePhotoHideInProgress = true;
    _cancelLivePhotoAsyncWork();
    livePhotoOpacity.value = 0.0;
    await Future.delayed(_livePhotoFadeDuration);
    if (!_isLivePhotoPlayActive(generation)) {
      _livePhotoHideInProgress = false;
      return;
    }
    isPlayingLivePhoto.value = false;
    _livePhotoHideInProgress = false;
  }

  Future<void> _stopLivePhotoPlayback({required bool disposePlayer}) async {
    _livePhotoHoldActive = false;
    _livePhotoPlayGeneration++;
    _livePhotoHideInProgress = false;
    _cancelLivePhotoAsyncWork();
    isDownloadingLivePhoto.value = false;

    final wasPlaying = isPlayingLivePhoto.value;
    if (wasPlaying) {
      livePhotoOpacity.value = 0.0;
      await Future.delayed(_livePhotoFadeDuration);
      if (mounted) {
        isPlayingLivePhoto.value = false;
      }
    }

    if (disposePlayer) {
      await _disposeLivePhotoPlayer();
    } else {
      try {
        await livePhotoPlayer?.pause();
        await livePhotoPlayer?.seek(Duration.zero);
      } catch (_) {}
    }
  }

  /// On clip end: tap mode fades out; hold mode freezes on the last frame until release.
  void _armLivePhotoPlaybackEnd(int generation, {required bool holdMode}) {
    final player = livePhotoPlayer;
    if (player == null) return;

    if (!holdMode) {
      void scheduleFromDuration(Duration duration) {
        if (!_isLivePhotoPlayActive(generation) || duration <= Duration.zero) return;
        if (_livePhotoHideTimer != null) return;
        final remaining = duration - player.state.position + const Duration(milliseconds: 100);
        _livePhotoHideTimer = Timer(
          remaining > Duration.zero ? remaining : Duration.zero,
          () => _hideLivePhotoOverlay(generation),
        );
      }

      scheduleFromDuration(player.state.duration);
      _livePhotoSubscriptions.add(player.stream.duration.listen(scheduleFromDuration));
    }

    var wasCompleted = player.state.completed;
    _livePhotoSubscriptions.add(player.stream.completed.listen((completed) {
      if (!_isLivePhotoPlayActive(generation)) return;
      final risingEdge = completed && !wasCompleted;
      wasCompleted = completed;
      if (!risingEdge) return;

      if (holdMode) {
        livePhotoPlayer?.pause();
      } else {
        _hideLivePhotoOverlay(generation);
      }
    }));
  }

  @override
  void dispose() {
    _livePhotoHoldActive = false;
    _livePhotoPlayGeneration++;
    _livePhotoPrepareGeneration++;
    _livePhotoHideInProgress = false;
    _cancelLivePhotoAsyncWork();
    livePhotoPlayer?.dispose();
    livePhotoPlayer = null;
    livePhotoController = null;
    super.dispose();
  }

  /// Get the persistent path for the live photo stored alongside the attachment
  String getLivePhotoPath() {
    final nameSplit = livePhotoAttachment.transferName!.split(".");
    final fileName = "${nameSplit.take(nameSplit.length - 1).join(".")}.mov";
    return "${livePhotoAttachment.directory}/$fileName";
  }

  /// Ensure the `.mov` is on disk (download if needed). Returns the path, or null on failure.
  Future<String?> _ensureLivePhotoOnDisk({required int prepareGeneration}) async {
    final livePhotoPath = getLivePhotoPath();
    final livePhotoFileOnDisk = File(livePhotoPath);

    if (await livePhotoFileOnDisk.exists()) {
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) return null;
      final fileInfo = await livePhotoFileOnDisk.stat();
      livePhotoFile = PlatformFile(
        name: p.basename(livePhotoPath),
        size: fileInfo.size,
        path: livePhotoPath,
      );
      return livePhotoPath;
    }

    isDownloadingLivePhoto.value = true;
    livePhotoProgress.value = 0.0;
    try {
      final response = await HttpSvc.attachment.downloadLivePhoto(
        livePhotoAttachment.guid!,
        onReceiveProgress: (count, total) {
          if (mounted && prepareGeneration == _livePhotoPrepareGeneration) {
            livePhotoProgress.value = total > 0 ? count / total : 0.0;
          }
        },
      );
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) {
        isDownloadingLivePhoto.value = false;
        return null;
      }

      await livePhotoFileOnDisk.parent.create(recursive: true);
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) {
        isDownloadingLivePhoto.value = false;
        return null;
      }
      await livePhotoFileOnDisk.writeAsBytes(response.data);
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) {
        isDownloadingLivePhoto.value = false;
        return null;
      }

      livePhotoFile = PlatformFile(
        name: p.basename(livePhotoPath),
        size: response.data.length,
        path: livePhotoPath,
      );
      isDownloadingLivePhoto.value = false;
      return livePhotoPath;
    } catch (ex, st) {
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) return null;
      Logger.error("Failed to download live photo", error: ex, trace: st);
      isDownloadingLivePhoto.value = false;
      return null;
    }
  }

  /// Open the player and mount a [Video] at opacity 0 *before* any hold gesture.
  /// Avoids Android cancelling the active pointer when a platform view is inserted mid-press.
  Future<void> prepareLivePhotoSurface() async {
    if (livePhotoController != null && livePhotoPlayer != null) {
      isLivePhotoSurfaceReady.value = true;
      _livePhotoKeepSurface = true;
      return;
    }

    final prepareGeneration = ++_livePhotoPrepareGeneration;
    _livePhotoKeepSurface = true;

    try {
      final path = await _ensureLivePhotoOnDisk(prepareGeneration: prepareGeneration);
      if (path == null || !mounted || prepareGeneration != _livePhotoPrepareGeneration) return;

      await _disposeLivePhotoPlayer();
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) return;

      final player = Player();
      livePhotoPlayer = player;
      livePhotoController = VideoController(player);
      await player.setPlaylistMode(PlaylistMode.none);
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) {
        await _disposeOwnedPlayer(player);
        return;
      }
      await player.open(Media(path), play: false);
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) {
        await _disposeOwnedPlayer(player);
        return;
      }

      // Mount Video at opacity 0 so the texture exists before the user holds.
      livePhotoOpacity.value = 0.0;
      isPlayingLivePhoto.value = false;
      isLivePhotoSurfaceReady.value = true;

      await player.play();
      await Future.delayed(_livePhotoFirstFrameGrace);
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) return;
      await player.pause();
      await player.seek(Duration.zero);
    } catch (ex, st) {
      if (!mounted || prepareGeneration != _livePhotoPrepareGeneration) return;
      Logger.error("Failed to prepare live photo surface", error: ex, trace: st);
      await _disposeLivePhotoPlayer();
    }
  }

  /// Tap-to-toggle playback (in-bubble LIVE badge / popup autoplay).
  Future<void> handleLivePhotoTap() async {
    if (isDownloadingLivePhoto.value || isPlayingLivePhoto.value) {
      if (isPlayingLivePhoto.value) {
        await _stopLivePhotoPlayback(disposePlayer: !_livePhotoKeepSurface);
      }
      return;
    }

    _livePhotoHoldActive = false;
    await _playLivePhoto(holdMode: false);
  }

  /// Begin press-and-hold playback (fullscreen). Plays only while held.
  Future<void> startLivePhotoHold() async {
    if (_livePhotoHoldActive || isDownloadingLivePhoto.value) return;

    _livePhotoHoldActive = true;
    _livePhotoKeepSurface = true;

    // Surface should already be mounted from [prepareLivePhotoSurface].
    if (livePhotoPlayer == null || livePhotoController == null) {
      await prepareLivePhotoSurface();
      if (!_livePhotoHoldActive || !mounted) return;
    }

    await _playLivePhoto(holdMode: true);
  }

  /// End press-and-hold: fade out early, or dismiss the frozen last frame.
  Future<void> endLivePhotoHold() async {
    if (!_livePhotoHoldActive) return;
    await _stopLivePhotoPlayback(disposePlayer: false);
  }

  Future<void> _playLivePhoto({required bool holdMode}) async {
    final generation = ++_livePhotoPlayGeneration;
    _livePhotoHideInProgress = false;
    _cancelLivePhotoAsyncWork();

    if (holdMode && !_livePhotoHoldActive) return;

    void clearHoldOnFailure() {
      if (holdMode && _isLivePhotoPlayActive(generation)) {
        _livePhotoHoldActive = false;
      }
    }

    Future<bool> playExistingSurface(Player player) async {
      try {
        await player.seek(Duration.zero);
        if (!_isLivePhotoPlayActive(generation) || !identical(livePhotoPlayer, player)) return false;

        await player.play();
        if (!_isLivePhotoPlayActive(generation) || !identical(livePhotoPlayer, player)) return false;

        await _revealLivePhotoOverlay(generation);
        if (!_isLivePhotoPlayActive(generation) || !identical(livePhotoPlayer, player)) return false;

        _armLivePhotoPlaybackEnd(generation, holdMode: holdMode);
        return true;
      } catch (ex, st) {
        if (!_isLivePhotoPlayActive(generation)) return false;
        Logger.warn("Live photo surface play failed, recreating", error: ex, trace: st);
        return false;
      }
    }

    // Prefer the pre-mounted fullscreen surface (no new platform view mid-gesture).
    if (holdMode && livePhotoPlayer != null && livePhotoController != null) {
      final ok = await playExistingSurface(livePhotoPlayer!);
      if (ok || !_isLivePhotoPlayActive(generation) || !_livePhotoHoldActive) return;
      await _disposeLivePhotoPlayer();
      if (!_isLivePhotoPlayActive(generation) || !_livePhotoHoldActive) return;
    }

    // Tap mode (or hold fallback): open a fresh player.
    if (!holdMode) {
      await _disposeLivePhotoPlayer();
      if (!_isLivePhotoPlayActive(generation)) return;
    }

    final prepareGeneration = _livePhotoPrepareGeneration;
    final path = await _ensureLivePhotoOnDisk(prepareGeneration: prepareGeneration);
    if (!_isLivePhotoPlayActive(generation)) return;
    if (path == null) {
      clearHoldOnFailure();
      showSnackbar("Error", "Failed to load live photo");
      return;
    }

    try {
      final player = Player();
      livePhotoPlayer = player;
      livePhotoController = VideoController(player);
      await player.setPlaylistMode(PlaylistMode.none);
      if (!_isLivePhotoPlayActive(generation)) {
        await _disposeOwnedPlayer(player);
        return;
      }
      await player.open(Media(path), play: false);
      if (!_isLivePhotoPlayActive(generation)) {
        await _disposeOwnedPlayer(player);
        return;
      }

      await player.play();
      if (!_isLivePhotoPlayActive(generation) || !identical(livePhotoPlayer, player)) {
        await _disposeOwnedPlayer(player);
        return;
      }

      await _revealLivePhotoOverlay(generation);
      if (!_isLivePhotoPlayActive(generation) || !identical(livePhotoPlayer, player)) return;

      _armLivePhotoPlaybackEnd(generation, holdMode: holdMode);
    } catch (ex, st) {
      if (!_isLivePhotoPlayActive(generation)) return;
      clearHoldOnFailure();
      await _disposeLivePhotoPlayer();
      Logger.error("Failed to play live photo", error: ex, trace: st);
      showSnackbar("Error", "Failed to play live photo");
    }
  }

  /// Build the live photo indicator widget
  Widget buildLivePhotoIndicator({required bool isFromMe}) {
    return GestureDetector(
      onTap: handleLivePhotoTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Obx(() => Stack(
              alignment: Alignment.center,
              children: [
                if (isDownloadingLivePhoto.value)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: livePhotoProgress.value,
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  )
                else if (isPlayingLivePhoto.value)
                  const Icon(
                    CupertinoIcons.pause_fill,
                    color: Colors.white,
                    size: 16,
                  )
                else
                  const Icon(
                    CupertinoIcons.smallcircle_circle,
                    color: Colors.white,
                    size: 20,
                  ),
              ],
            )),
      ),
    );
  }

  /// Build the live photo video overlay.
  /// Mounts whenever the surface is ready (including opacity 0 pre-warm) so hold
  /// playback never inserts a new platform view under an active pointer.
  Widget buildLivePhotoOverlay() {
    return Obx(() {
      final mountedSurface = isLivePhotoSurfaceReady.value && livePhotoController != null;
      final playing = isPlayingLivePhoto.value && livePhotoController != null;
      if (!mountedSurface && !playing) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: IgnorePointer(
          child: Obx(
            () => AnimatedOpacity(
              opacity: livePhotoOpacity.value,
              duration: _livePhotoFadeDuration,
              curve: Curves.easeInOut,
              child: Video(
                controller: livePhotoController!,
                fit: BoxFit.contain,
                fill: Colors.transparent,
                controls: null,
              ),
            ),
          ),
        ),
      );
    });
  }
}
