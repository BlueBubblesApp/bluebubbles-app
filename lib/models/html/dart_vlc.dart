import 'package:flutter/material.dart';

/// READ: Dummy file to allow dart_vlc related code to compile on Web. We use
/// conditional imports at compile time, so any references to dart_vlc stuff
/// will error if this file is removed. The below classes and methods are the ones
/// that we use from dart_vlc, in case we need to add more dart_vlc
/// functionality to the app, the new classes/methods must be added here.

class DartVLC {
  static void initialize() => throw Exception('Unsupported Platform');
}

/// State of a [Player] instance.
class CurrentState {
  /// Index of currently playing [Media].
  int? index;

  /// Currently playing [Media].
  Media? media;

  /// [List] of [Media] currently opened in the [Player] instance.
  List<Media> medias = <Media>[];

  /// Whether a [Playlist] is opened or a [Media].
  bool isPlaylist = false;
}

/// Playback state of a [Player] instance.
class PlaybackState {
  /// Whether [Player] instance is playing or not.
  bool isPlaying = false;

  /// Whether [Player] instance is seekable or not.
  bool isSeekable = true;

  /// Whether the current [Media] has ended playing or not.
  bool isCompleted = false;
}

// Represents dimensions of a video.
class VideoDimensions {
  /// Width of the video.
  final int width;

  /// Height of the video.
  final int height;
  const VideoDimensions(this.width, this.height);

  @override
  String toString() => 'VideoDimensions($width, $height)';
}

class Player {
  late Stream<PlaybackState> playbackStream;

  /// Playback state of the [Player] instance.
  PlaybackState playback = PlaybackState();

  /// State of the current & opened [MediaSource] in [Player] instance.
  CurrentState current = CurrentState();

  /// Dimensions of the currently playing video.
  VideoDimensions videoDimensions = const VideoDimensions(0, 0);

  Player({
    required int id,
  });

  /// Plays opened [MediaSource],
  void play() {
  }

  /// Pauses opened [MediaSource],
  void pause() {
  }

  /// Play or Pause opened [MediaSource],
  void playOrPause() {
  }

  /// Stops the [Player].
  ///
  /// Also resets the [Device] set using [Player.setDevice].
  /// A new instance must be created, once this method is called.
  ///
  void stop() {
  }

  /// Jumps to the next [Media] in the [Playlist] opened.
  void next() {
  }

  /// Jumps to the previous [Media] in the [Playlist] opened.
  void previous() {
  }

  /// Jumps to [Media] at specific index in the [Playlist] opened.
  /// Pass index as parameter.
  void jumpToIndex(int index) {
  }

  /// Seeks the [Media] currently playing in the [Player] instance, to the provided [Duration].
  void seek(Duration duration) {
  }

  /// Sets volume of the [Player] instance.
  void setVolume(double volume) {
  }

  /// Sets playback rate of the [Media] currently playing in the [Player] instance.
  void setRate(double rate) {
  }

  /// Sets user agent for dart_vlc player.
  void setUserAgent(String userAgent) {
  }

  /// Changes [Playlist] playback mode.
  void setPlaylistMode(dynamic playlistMode) {
  }

  /// Appends [Media] to the [Playlist] of the [Player] instance.
  void add(dynamic source) {
  }

  /// Removes [Media] from the [Playlist] at a specific index.
  void remove(int index) {
  }

  /// Inserts [Media] to the [Playlist] of the [Player] instance at specific index.
  void insert(int index, dynamic source) {
  }

  /// Moves [Media] already present in the [Playlist] of the [Player] from [initialIndex] to [finalIndex].
  void move(int initialIndex, int finalIndex) {
  }

  /// Sets playback [Device] for the instance of [Player].
  ///
  /// Use [Devices.all] getter to get [List] of all [Device].
  ///
  /// A playback [Device] for a [Player] instance cannot be changed in the middle of playback.
  /// Device will be switched once a new [Media] is played.
  ///
  void setDevice(dynamic device) {
  }

  /// Sets [Equalizer] for the [Player].
  void setEqualizer(dynamic equalizer) {
  }

  /// Saves snapshot of a video to a desired [File] location.
  void takeSnapshot(dynamic file, int width, int height) {
  }

  /// Sets Current Audio Track for the current [MediaSource]
  void setAudioTrack(int track) {
  }

  /// Gets audio track count from current [MediaSource]
  int get audioTrackCount {
    return 0;
  }

  void setHWND(int hwnd) {
  }

  /// Destroys the instance of [Player] & closes all [StreamController]s in it.
  void dispose() {
  }
}

class Media {
  final String resource;
  final Map<String, String> metas;

  const Media._({
    required this.resource,
    required this.metas,
  });

  /// Makes [Media] object from a [File].
  factory Media.file(
      dynamic file
  ) {
    return const Media._(resource: "", metas: {});
  }
}

class Video extends StatefulWidget {
  /// {@macro video}
  Video({
    Player? player,
    bool? showControls = true,
    bool? showTimeLeft = false,
    Color? fillColor = Colors.black,
    Alignment? alignment = Alignment.center,
  });

  @override
  State<StatefulWidget> createState() {
    throw UnimplementedError();
  }
}