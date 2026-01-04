import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../protocol/messages.dart';
import 'session_provider.dart';

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

// Provider for sending commands to the player
final playerCommandProvider = StateProvider<CommandMessage?>((ref) => null);

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref ref;

  PlayerNotifier(this.ref) : super(const PlayerState());

  void updateFromJs(Map<String, dynamic> data) {
    final jsState = data['playerState'] as int?;
    final isPlaying = jsState == 1; // YT.PlayerState.PLAYING = 1

    state = state.copyWith(
      isPlaying: isPlaying,
      currentPositionSeconds: (data['currentTime'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
      volume: (data['volume'] as num?)?.toInt() ?? 100,
      currentVideoId: data['videoId'] as String?,
      currentTitle: data['title'] as String?,
      status: _mapStatus(jsState),
    );

    // Broadcast state to server if host
    _broadcastState();
  }

  PlayerStatus _mapStatus(int? ytState) {
    switch (ytState) {
      case -1:
        return PlayerStatus.idle;
      case 0:
        return PlayerStatus.ended;
      case 1:
        return PlayerStatus.playing;
      case 2:
        return PlayerStatus.paused;
      case 3:
        return PlayerStatus.buffering;
      case 5:
        return PlayerStatus.loading;
      default:
        return PlayerStatus.idle;
    }
  }

  void _broadcastState() {
    final sessionState = ref.read(sessionProvider);
    if (sessionState.isHost && sessionState.isConnected) {
      sessionState.session;
      // Server will broadcast state to all clients
      ref.read(sessionProvider.notifier).server?.updatePlayerState(state);
    }
  }

  void play() {
    _sendCommand(CommandMessage.play());
    state = state.copyWith(isPlaying: true);
  }

  void pause() {
    _sendCommand(CommandMessage.pause());
    state = state.copyWith(isPlaying: false);
  }

  void seek(int seconds) {
    _sendCommand(CommandMessage.seek(seconds.toDouble()));
    state = state.copyWith(currentPositionSeconds: seconds.clamp(0, state.totalDurationSeconds));
  }

  void setVolume(int volume) {
    _sendCommand(CommandMessage.volume(volume));
    state = state.copyWith(volume: volume.clamp(0, 100));
  }

  void loadVideo(String videoId, {String? title}) {
    _sendCommand(CommandMessage.load(videoId));
    state = state.copyWith(
      currentVideoId: videoId,
      currentTitle: title ?? state.currentTitle, // Preserve existing title or use provided title
      status: PlayerStatus.loading,
    );
  }

  void requestVideoTitle(String videoId) {
    _sendCommand(CommandMessage.requestTitle(videoId));
  }

  void _sendCommand(CommandMessage command) {
    final sessionState = ref.read(sessionProvider);

    if (sessionState.isHost) {
      // If host, trigger command directly via provider
      ref.read(playerCommandProvider.notifier).state = command;
    } else {
      // If guest, send to server
      sessionState;
      ref.read(sessionProvider.notifier).client?.sendCommand(
            command.action,
            command.value,
          );
    }
  }

  void updateState(PlayerState newState) {
    state = newState;
  }
}
