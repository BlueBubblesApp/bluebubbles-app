import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

/// Full-screen camera review screen. Launches the native system camera via
/// [ImagePicker] immediately on push, then presents the captured photo/video
/// for review with pinch-to-zoom, double-tap-to-zoom, and a Retake / Use bar.
///
/// Returns the captured [XFile] via [Navigator.pop], or `null` if the user
/// cancels. Only rendered on Android; callers should guard with
/// `Platform.isAndroid && !kIsWeb` before pushing this route.
class CameraScreen extends StatefulWidget {
  /// 'photo' (default) or 'video'.
  final String initialMode;

  const CameraScreen({super.key, this.initialMode = 'photo'});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  XFile? _previewFile;
  bool _isVideo = false;

  final TransformationController _previewTransformController = TransformationController();
  Offset _previewDoubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureMedia());
  }

  @override
  void dispose() {
    _previewTransformController.dispose();
    super.dispose();
  }

  Future<void> _captureMedia() async {
    final picker = ImagePicker();
    final XFile? file;
    if (widget.initialMode == 'video') {
      file = await picker.pickVideo(source: ImageSource.camera);
    } else {
      // imageQuality is intentionally omitted — any value, including 100,
      // causes image_picker to re-encode the JPEG which loses native processing
      // (HDR tone-mapping, computational photography, etc.).  Omitting it
      // returns the file exactly as the camera app wrote it.
      file = await picker.pickImage(source: ImageSource.camera);
    }

    if (!mounted) return;

    if (file == null) {
      Navigator.of(context).pop(null);
      return;
    }

    setState(() {
      _isVideo = widget.initialMode == 'video';
      _previewFile = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _previewFile != null ? _buildConfirmOverlay(_previewFile!) : const SizedBox.shrink(),
    );
  }

  Widget _buildConfirmOverlay(XFile file) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen interactive preview (pinch-to-zoom + double-tap)
          GestureDetector(
            onDoubleTapDown: (d) => _previewDoubleTapPosition = d.localPosition,
            onDoubleTap: () {
              final isZoomedIn = _previewTransformController.value != Matrix4.identity();
              if (isZoomedIn) {
                _previewTransformController.value = Matrix4.identity();
              } else {
                final m = Matrix4.identity()
                  ..translateByDouble(
                    -_previewDoubleTapPosition.dx * (2.5 - 1),
                    -_previewDoubleTapPosition.dy * (2.5 - 1),
                    0,
                    1,
                  )
                  ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
                _previewTransformController.value = m;
              }
            },
            child: InteractiveViewer(
              transformationController: _previewTransformController,
              minScale: 1.0,
              maxScale: 4.0,
              boundaryMargin: EdgeInsets.zero,
              child: Center(
                child: _isVideo ? _VideoPreview(file: file) : Image.file(File(file.path), fit: BoxFit.contain),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: 8,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ),
          ),

          // Retake / Use bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Retake', style: TextStyle(color: Colors.white, fontSize: 16)),
                      onPressed: () {
                        _previewTransformController.value = Matrix4.identity();
                        setState(() => _previewFile = null);
                        _captureMedia();
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text('Use', style: TextStyle(color: Colors.white, fontSize: 16)),
                      onPressed: () => Navigator.of(context).pop(file),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final XFile file;

  const _VideoPreview({required this.file});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _videoController;
  bool _initialized = false;
  bool _muted = false;

  /// Whether the control bar is currently visible.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.file.path));
    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _videoController.setLooping(true);
        _videoController.play();
        _scheduleHide();
      }
    });
    // Rebuild on every position tick so the seek bar updates smoothly.
    _videoController.addListener(_onVideoTick);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoController.removeListener(_onVideoTick);
    _videoController.dispose();
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  // ── Controls visibility ────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  // ── Playback helpers ───────────────────────────────────────────────────

  void _togglePlay() {
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _hideTimer?.cancel(); // keep controls visible while paused
      } else {
        _videoController.play();
        _scheduleHide();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _videoController.setVolume(_muted ? 0.0 : 1.0);
    });
    _scheduleHide();
  }

  // ── Formatting ─────────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final value = _videoController.value;
    final total = value.duration.inMilliseconds.toDouble();
    final position = value.position.inMilliseconds.toDouble().clamp(0.0, total);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController),

            // Tap-to-reveal scrim + controls
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Gradient scrim so controls are readable over any content
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // Center play/pause button
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            key: ValueKey(value.isPlaying),
                            color: Colors.white,
                            size: 68,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
                          ),
                        ),
                      ),
                    ),

                    // Bottom bar: seek + time + mute
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Seek slider
                            SliderTheme(
                              data: const SliderThemeData(
                                trackHeight: 2.5,
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white38,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white24,
                              ),
                              child: Slider(
                                value: total > 0 ? position / total : 0.0,
                                onChangeStart: (_) => _hideTimer?.cancel(),
                                onChanged: total > 0
                                    ? (v) {
                                        final target = Duration(milliseconds: (v * total).round());
                                        _videoController.seekTo(target);
                                      }
                                    : null,
                                onChangeEnd: (_) {
                                  if (_videoController.value.isPlaying) _scheduleHide();
                                },
                              ),
                            ),

                            // Time labels + mute button
                            Row(
                              children: [
                                Text(
                                  _formatDuration(value.position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const Text(
                                  ' / ',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                Text(
                                  _formatDuration(value.duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _toggleMute,
                                  child: Icon(
                                    _muted ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
