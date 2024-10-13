import 'dart:async';

import 'package:flutter/material.dart';

abstract class MediaKit {
  /// {@macro media_kit}
  static void ensureInitialized({String? libmpv}) {}
}

class PlayerState {
  /// Whether [Player] is playing or not.
  final bool playing;

  /// Whether currently playing [Media] in [Player] has ended or not.
  final bool completed;

  /// Current playback position of the [Player].
  final Duration position;

  /// Duration of the currently playing [Media] in the [Player].
  final Duration duration;

  /// Current volume of the [Player].
  final double volume;

  /// Current playback rate of the [Player].
  final double rate;

  /// Current pitch of the [Player].
  final double pitch;

  /// Whether the [Player] is buffering.
  final bool buffering;

  /// The total buffered duration of the currently playing [Media] in the [Player].
  /// This indicates how much of the stream has been decoded & cached by the demuxer.
  final Duration buffer;

  /// Audio bitrate of the currently playing [Media].
  final double? audioBitrate;

  /// Currently playing video's width.
  final int? width;

  /// Currently playing video's height.
  final int? height;

  /// {@macro player_state}
  const PlayerState({
    this.playing = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.volume = 1.0,
    this.rate = 1.0,
    this.pitch = 1.0,
    this.buffering = false,
    this.audioBitrate,
    this.width,
    this.height,
  });
}

class Player {
  PlayerState get state => throw Exception();
  PlayerStreams get stream => throw Exception();

  FutureOr<void> dispose({int code = 0}) {}

  FutureOr<void> open(dynamic playable, {
    bool play = true,
  }) {}

  /// Starts playing the [Player].
  FutureOr<void> play() {}

  /// Pauses the [Player].
  FutureOr<void> pause() {}

  /// Cycles between [play] & [pause] states of the [Player].
  FutureOr<void> playOrPause() {}

  /// Appends a [Media] to the [Player]'s playlist.
  FutureOr<void> add(Media media) {}

  /// Removes the [Media] at specified index from the [Player]'s playlist.
  FutureOr<void> remove(int index) {}

  /// Jumps to next [Media] in the [Player]'s playlist.
  FutureOr<void> next() {}

  /// Jumps to previous [Media] in the [Player]'s playlist.
  FutureOr<void> previous() {}

  /// Jumps to specified [Media]'s index in the [Player]'s playlist.
  FutureOr<void> jump(int index) {}

  /// Moves the playlist [Media] at [from], so that it takes the place of the [Media] [to].
  FutureOr<void> move(int from, int to) {}

  /// Seeks the currently playing [Media] in the [Player] by specified [Duration].
  FutureOr<void> seek(Duration duration) {}

  /// Sets playlist mode.
  FutureOr<void> setPlaylistMode(PlaylistMode playlistMode) {}

  /// Sets the playback volume of the [Player].
  /// Defaults to `100.0`.
  FutureOr<void> setVolume(double volume) {}

  /// Sets the playback rate of the [Player].
  /// Defaults to `1.0`.
  FutureOr<void> setRate(double rate) {}

  /// Sets the relative pitch of the [Player].
  /// Defaults to `1.0`.
  FutureOr<void> setPitch(double pitch) {}

  /// Enables or disables shuffle for [Player].
  /// Default is `false`.
  FutureOr<void> setShuffle(bool shuffle) {}
}

class VideoController {
  /// The [Player] instance associated with this [VideoController].
  final Player player;

  final ValueNotifier<Rect?> rect = ValueNotifier<Rect?>(null);

  VideoController(
      this.player,
  );

  static Future<VideoController> create(
    Player player, {
      int? width,
      int? height,
      bool enableHardwareAcceleration = true,
    }) async {
      throw Exception();
    }

  /// Disposes the [VideoController].
  /// Releases the allocated resources back to the system.
  Future<void> dispose() async {}
}

class Video extends StatefulWidget {
  /// The [VideoController] reference to control this [Video] output & connect with [Player] from `package:media_kit`.
  final VideoController? controller;

  /// {@macro video}
  const Video({
    super.key,
    required this.controller,
  });

  @override
  State<Video> createState() => throw Exception();
}

class Media {
  /// URI of the [Media].
  final String uri;

  /// {@macro media}
  Media(this.uri);
}

enum PlaylistMode {
  /// End playback once end of the playlist is reached.
  none,

  /// Indefinitely loop over the currently playing file in the playlist.
  single,

  /// Loop over the playlist & restart it from beginning once end is reached.
  loop,
}

class PlayerStreams {
  /// [List] of currently opened [Media]s.
  final Stream<dynamic> playlist;

  /// Whether [Player] is playing or not.
  final Stream<bool> playing;

  /// Whether currently playing [Media] in [Player] has ended or not.
  final Stream<bool> completed;

  /// Current playback position of the [Player].
  final Stream<Duration> position;

  /// Duration of the currently playing [Media] in the [Player].
  final Stream<Duration> duration;

  /// The total buffered duration of the currently playing [Media] in the [Player].
  /// This indicates how much of the stream has been decoded & cached by the demuxer.
  final Stream<Duration> buffer;

  /// Current volume of the [Player].
  final Stream<double> volume;

  /// Current playback rate of the [Player].
  final Stream<double> rate;

  /// Current pitch of the [Player].
  final Stream<double> pitch;

  /// Whether the [Player] has stopped for buffering.
  final Stream<bool> buffering;

  /// Audio bitrate of the currently playing [Media] in the [Player].
  final Stream<double?> audioBitrate;

  /// Currently playing video's width.
  final Stream<int> width;

  /// Currently playing video's height.
  final Stream<int> height;

  /// {@macro player_streams}
  const PlayerStreams(
      this.playlist,
      this.playing,
      this.completed,
      this.position,
      this.duration,
      this.buffer,
      this.volume,
      this.rate,
      this.pitch,
      this.buffering,
      this.audioBitrate,
      this.width,
      this.height,
      );
}