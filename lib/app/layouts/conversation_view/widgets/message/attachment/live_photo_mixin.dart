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

  /// Bumped on dispose and each new play so in-flight awaits no-op after teardown.
  int _livePhotoPlayGeneration = 0;
  Timer? _livePhotoHideTimer;
  final List<StreamSubscription<dynamic>> _livePhotoSubscriptions = [];

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
    await player?.dispose();
  }

  void _scheduleLivePhotoHide(int generation, Duration delay) {
    _livePhotoHideTimer?.cancel();
    _livePhotoHideTimer = Timer(delay, () async {
      if (!_isLivePhotoPlayActive(generation) || !isPlayingLivePhoto.value) return;
      livePhotoOpacity.value = 0.0;
      await Future.delayed(const Duration(milliseconds: 200));
      if (!_isLivePhotoPlayActive(generation)) return;
      isPlayingLivePhoto.value = false;
    });
  }

  @override
  void dispose() {
    _livePhotoPlayGeneration++;
    _cancelLivePhotoAsyncWork();
    livePhotoPlayer?.dispose();
    livePhotoPlayer = null;
    livePhotoController = null;
    super.dispose();
  }

  /// Get the persistent path for the live photo stored alongside the attachment
  String getLivePhotoPath() {
    // Store in same directory as attachment: {appDocDir}/attachments/{guid}/{name}.mov
    final nameSplit = livePhotoAttachment.transferName!.split(".");
    final fileName = "${nameSplit.take(nameSplit.length - 1).join(".")}.mov";
    return "${livePhotoAttachment.directory}/$fileName";
  }

  Future<void> handleLivePhotoTap() async {
    if (isDownloadingLivePhoto.value || isPlayingLivePhoto.value) {
      // If already playing, stop it with fade out
      if (isPlayingLivePhoto.value) {
        _livePhotoPlayGeneration++;
        _cancelLivePhotoAsyncWork();
        livePhotoOpacity.value = 0.0;
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          isPlayingLivePhoto.value = false;
          await livePhotoPlayer?.pause();
        }
      }
      return;
    }

    final generation = ++_livePhotoPlayGeneration;
    _cancelLivePhotoAsyncWork();

    // Check if we already have the live photo cached in memory
    if (livePhotoFile != null && livePhotoPlayer != null) {
      try {
        // Seek to start and wait for player to be ready
        await livePhotoPlayer!.seek(Duration.zero);
        if (!_isLivePhotoPlayActive(generation)) return;

        // Start playing (but keep hidden while loading)
        await livePhotoPlayer!.play();
        if (!_isLivePhotoPlayActive(generation)) return;

        // Wait a bit for the video to buffer the first frame
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isLivePhotoPlayActive(generation)) return;

        isPlayingLivePhoto.value = true;

        // Fade in
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isLivePhotoPlayActive(generation)) return;
        livePhotoOpacity.value = 1.0;

        // Auto-hide after video ends with fade out
        _scheduleLivePhotoHide(
          generation,
          Duration(milliseconds: livePhotoPlayer!.state.duration.inMilliseconds + 100),
        );
      } catch (ex) {
        if (!_isLivePhotoPlayActive(generation)) return;
        Logger.error("Failed to play live photo", error: ex);
        showSnackbar("Error", "Failed to play live photo");
      }
      return;
    }

    // Get persistent storage path
    final livePhotoPath = getLivePhotoPath();
    final livePhotoFileOnDisk = File(livePhotoPath);

    // Check if live photo already exists on disk
    if (await livePhotoFileOnDisk.exists()) {
      if (!_isLivePhotoPlayActive(generation)) return;

      // Initialize and play existing file
      try {
        final fileInfo = await livePhotoFileOnDisk.stat();
        if (!_isLivePhotoPlayActive(generation)) return;

        livePhotoFile = PlatformFile(
          name: p.basename(livePhotoPath),
          size: fileInfo.size,
          path: livePhotoPath,
        );

        livePhotoPlayer = Player();
        livePhotoController = VideoController(livePhotoPlayer!);
        await livePhotoPlayer!.setPlaylistMode(PlaylistMode.none);
        if (!_isLivePhotoPlayActive(generation)) {
          await _disposeLivePhotoPlayer();
          return;
        }
        await livePhotoPlayer!.open(Media(livePhotoPath), play: false);
        if (!_isLivePhotoPlayActive(generation)) {
          await _disposeLivePhotoPlayer();
          return;
        }

        // Start playing and wait for first frame to be ready
        await livePhotoPlayer!.play();
        if (!_isLivePhotoPlayActive(generation)) {
          await _disposeLivePhotoPlayer();
          return;
        }
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isLivePhotoPlayActive(generation)) {
          await _disposeLivePhotoPlayer();
          return;
        }

        isPlayingLivePhoto.value = true;

        // Fade in
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isLivePhotoPlayActive(generation)) return;
        livePhotoOpacity.value = 1.0;

        // Auto-hide after video ends with fade out
        _scheduleLivePhotoHide(
          generation,
          Duration(milliseconds: livePhotoPlayer!.state.duration.inMilliseconds + 100),
        );
      } catch (ex) {
        if (!_isLivePhotoPlayActive(generation)) return;
        Logger.error("Failed to play existing live photo", error: ex);
        showSnackbar("Error", "Failed to play live photo", type: SnackbarType.error);
      }
      return;
    }

    // Download the live photo
    isDownloadingLivePhoto.value = true;
    livePhotoProgress.value = 0.0;

    try {
      final response = await HttpSvc.attachment.downloadLivePhoto(
        livePhotoAttachment.guid!,
        onReceiveProgress: (count, total) {
          if (_isLivePhotoPlayActive(generation)) {
            livePhotoProgress.value = total > 0 ? count / total : 0.0;
          }
        },
      );
      if (!_isLivePhotoPlayActive(generation)) {
        isDownloadingLivePhoto.value = false;
        return;
      }

      // Save to persistent location alongside attachment
      // Create directory if it doesn't exist
      await livePhotoFileOnDisk.parent.create(recursive: true);
      if (!_isLivePhotoPlayActive(generation)) {
        isDownloadingLivePhoto.value = false;
        return;
      }
      await livePhotoFileOnDisk.writeAsBytes(response.data);
      if (!_isLivePhotoPlayActive(generation)) {
        isDownloadingLivePhoto.value = false;
        return;
      }

      livePhotoFile = PlatformFile(
        name: p.basename(livePhotoPath),
        size: response.data.length,
        path: livePhotoPath,
      );

      // Initialize video player
      livePhotoPlayer = Player();
      livePhotoController = VideoController(livePhotoPlayer!);
      await livePhotoPlayer!.setPlaylistMode(PlaylistMode.none);
      if (!_isLivePhotoPlayActive(generation)) {
        isDownloadingLivePhoto.value = false;
        await _disposeLivePhotoPlayer();
        return;
      }
      await livePhotoPlayer!.open(Media(livePhotoPath), play: false);
      if (!_isLivePhotoPlayActive(generation)) {
        isDownloadingLivePhoto.value = false;
        await _disposeLivePhotoPlayer();
        return;
      }

      isDownloadingLivePhoto.value = false;

      // Start playback and wait for first frame to be ready
      await livePhotoPlayer!.play();
      if (!_isLivePhotoPlayActive(generation)) {
        await _disposeLivePhotoPlayer();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isLivePhotoPlayActive(generation)) {
        await _disposeLivePhotoPlayer();
        return;
      }

      isPlayingLivePhoto.value = true;

      // Fade in
      await Future.delayed(const Duration(milliseconds: 50));
      if (!_isLivePhotoPlayActive(generation)) return;
      livePhotoOpacity.value = 1.0;

      // Auto-hide after video ends with fade out
      _scheduleLivePhotoHide(
        generation,
        Duration(milliseconds: livePhotoPlayer!.state.duration.inMilliseconds + 100),
      );
    } catch (ex) {
      if (!_isLivePhotoPlayActive(generation)) return;
      Logger.error("Failed to download/play live photo", error: ex);
      isDownloadingLivePhoto.value = false;
      showSnackbar("Error", "Failed to load live photo", type: SnackbarType.error);
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

  /// Build the live photo video overlay
  Widget buildLivePhotoOverlay() {
    return Obx(() {
      if (!isPlayingLivePhoto.value || livePhotoController == null) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: AnimatedOpacity(
          opacity: livePhotoOpacity.value,
          duration: const Duration(milliseconds: 200),
          child: Video(
            controller: livePhotoController!,
            fit: BoxFit.contain,
            controls: null,
          ),
        ),
      );
    });
  }
}
