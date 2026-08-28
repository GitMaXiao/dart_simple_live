import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';

class LiveAudioHandler extends BaseAudioHandler with SeekHandler {
  Future<void> Function()? onPlayCallback;
  Future<void> Function()? onPauseCallback;
  Future<void> Function()? onStopCallback;

  LiveAudioHandler() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.pause,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  void updateMetadata({
    required String id,
    required String title,
    required String artist,
    String? artUri,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        album: "Simple Live 直播",
        title: title,
        artist: artist,
        artUri: artUri != null && artUri.isNotEmpty ? Uri.tryParse(artUri) : null,
      ),
    );
  }

  void setPlaybackState({
    required bool isPlaying,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: processingState,
        playing: isPlaying,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (onPlayCallback != null) {
      await onPlayCallback!();
    }
  }

  @override
  Future<void> pause() async {
    if (onPauseCallback != null) {
      await onPauseCallback!();
    }
  }

  @override
  Future<void> stop() async {
    if (onStopCallback != null) {
      await onStopCallback!();
    }
    playbackState.add(
      PlaybackState(
        controls: [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    mediaItem.add(null);
  }
}

class LiveAudioService extends GetxService {
  static LiveAudioService get instance => Get.find<LiveAudioService>();

  LiveAudioHandler? audioHandler;

  Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      audioHandler = await AudioService.init(
        builder: () => LiveAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.xycz.simple_live.channel.audio',
          androidNotificationChannelName: 'Simple Live 后台播放',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
      Log.i("LiveAudioService 初始化成功");
    } catch (e, stackTrace) {
      Log.e("LiveAudioService 初始化失败: $e", stackTrace);
    }
  }

  void startSession({
    required String roomId,
    required String title,
    required String artist,
    String? artUri,
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function()? onStop,
  }) {
    if (audioHandler == null) return;
    audioHandler!.onPlayCallback = onPlay;
    audioHandler!.onPauseCallback = onPause;
    audioHandler!.onStopCallback = onStop;
    audioHandler!.updateMetadata(
      id: roomId,
      title: title,
      artist: artist,
      artUri: artUri,
    );
    audioHandler!.setPlaybackState(isPlaying: true);
  }

  void updatePlayingState(bool isPlaying) {
    if (audioHandler == null) return;
    audioHandler!.setPlaybackState(isPlaying: isPlaying);
  }

  void stopSession() {
    if (audioHandler == null) return;
    audioHandler!.stop();
  }
}

