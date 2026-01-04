import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../protocol/messages.dart';
import 'session_provider.dart';
import 'player_provider.dart';

final queueProvider = StateNotifierProvider<QueueNotifier, MusicQueue>((ref) {
  return QueueNotifier(ref);
});

class QueueNotifier extends StateNotifier<MusicQueue> {
  final Ref ref;
  static const _uuid = Uuid();

  QueueNotifier(this.ref) : super(const MusicQueue());

  Future<void> addSongFromUrl(String input) async {
    debugPrint('[QueueProvider] addSongFromUrl called with: $input');

    // Send the raw URL to the player HTML to process
    // The player will handle playlist expansion and return video info
    ref.read(playerProvider.notifier).loadVideo(input);
  }


  void addSong(Song song) {
    debugPrint('[QueueProvider] addSong called: ${song.title} (videoId: ${song.videoId})');
    final sessionState = ref.read(sessionProvider);
    debugPrint('[QueueProvider] isHost: ${sessionState.isHost}');

    if (sessionState.isHost) {
      // Host adds directly
      state = state.addSong(song);
      debugPrint('[QueueProvider] Queue updated. Length: ${state.length}, currentIndex: ${state.currentIndex}');
      _broadcastQueueUpdate(QueueUpdateReason.added);
    } else {
      // Guest sends to server
      ref.read(sessionProvider.notifier).client?.addToQueue(song);
    }
  }

  /// Called when HTML player sends back video info after processing URL
  void addSongFromPlayerResponse(Map<String, dynamic> videoInfo) {
    debugPrint('[QueueProvider] addSongFromPlayerResponse: $videoInfo');

    final videoId = videoInfo['videoId'] as String;

    // Check if this video is already in the queue (for playlist updates)
    final existingSongIndex = state.songs.indexWhere((s) => s.videoId == videoId);

    if (existingSongIndex != -1) {
      // Update existing song with real info
      final existingSong = state.songs[existingSongIndex];
      final updatedSong = Song(
        id: existingSong.id,
        videoId: videoId,
        title: videoInfo['title'] as String? ?? existingSong.title,
        artist: videoInfo['author'] as String? ?? existingSong.artist,
        thumbnailUrl: videoInfo['thumbnail'] as String? ?? existingSong.thumbnailUrl,
        durationSeconds: (videoInfo['duration'] as num?)?.toInt() ?? existingSong.durationSeconds,
        addedBy: existingSong.addedBy,
        addedByName: existingSong.addedByName,
        addedAt: existingSong.addedAt,
      );

      final updatedSongs = List<Song>.from(state.songs);
      updatedSongs[existingSongIndex] = updatedSong;

      state = state.copyWith(songs: updatedSongs);
      debugPrint('[QueueProvider] Updated song info: ${updatedSong.title}');
      _broadcastQueueUpdate(QueueUpdateReason.added);
    } else {
      // Add new song
      final sessionState = ref.read(sessionProvider);
      final currentUser = sessionState.currentUser;

      final song = Song(
        id: _uuid.v4(),
        videoId: videoId,
        title: videoInfo['title'] as String? ?? 'Unknown Title',
        artist: videoInfo['author'] as String?,
        thumbnailUrl: videoInfo['thumbnail'] as String? ?? '',
        durationSeconds: (videoInfo['duration'] as num?)?.toInt() ?? 0,
        addedBy: currentUser?.id ?? '',
        addedByName: currentUser?.name ?? 'Unknown',
        addedAt: DateTime.now(),
      );

      addSong(song);
    }
  }

  /// Called when HTML player sends updated video info (e.g., real title for playlist video)
  void updateSongFromPlayerResponse(Map<String, dynamic> videoInfo) {
    debugPrint('[QueueProvider] updateSongFromPlayerResponse: $videoInfo');

    final videoId = videoInfo['videoId'] as String;

    // Find the song by videoId and update it
    final songIndex = state.songs.indexWhere((s) => s.videoId == videoId);
    if (songIndex == -1) {
      debugPrint('[QueueProvider] Song not found for update: $videoId');
      return;
    }

    final oldSong = state.songs[songIndex];
    final updatedSong = Song(
      id: oldSong.id,
      videoId: oldSong.videoId,
      title: videoInfo['title'] as String? ?? oldSong.title,
      artist: videoInfo['author'] as String? ?? oldSong.artist,
      thumbnailUrl: videoInfo['thumbnail'] as String? ?? oldSong.thumbnailUrl,
      durationSeconds: (videoInfo['duration'] as num?)?.toInt() ?? oldSong.durationSeconds,
      addedBy: oldSong.addedBy,
      addedByName: oldSong.addedByName,
      addedAt: oldSong.addedAt,
    );

    final updatedSongs = List<Song>.from(state.songs);
    updatedSongs[songIndex] = updatedSong;

    state = state.copyWith(songs: updatedSongs);
    debugPrint('[QueueProvider] Updated song: ${updatedSong.title}');

    _broadcastQueueUpdate(QueueUpdateReason.added);
  }

  void removeSong(String songId) {
    final sessionState = ref.read(sessionProvider);

    if (sessionState.isHost) {
      state = state.removeSong(songId);
      _broadcastQueueUpdate(QueueUpdateReason.removed);
    } else {
      // Guest sends remove request to server
      ref.read(sessionProvider.notifier).client?.removeFromQueue(
            songId,
            sessionState.currentUser?.id ?? '',
          );
    }
  }

  void playNext() {
    state = state.playNext();
    _broadcastQueueUpdate(QueueUpdateReason.skipped);

    // Load the new current song
    final currentSong = state.currentSong;
    if (currentSong != null) {
      debugPrint('[QueueProvider] Playing next: ${currentSong.videoId}');
      ref.read(playerProvider.notifier).loadVideo(currentSong.videoId, title: currentSong.title);
    }
  }

  void playPrevious() {
    state = state.playPrevious();
    _broadcastQueueUpdate(QueueUpdateReason.skipped);

    // Load the new current song
    final currentSong = state.currentSong;
    if (currentSong != null) {
      debugPrint('[QueueProvider] Playing previous: ${currentSong.videoId}');
      ref.read(playerProvider.notifier).loadVideo(currentSong.videoId, title: currentSong.title);
    }
  }

  void playAtIndex(int index) {
    if (index < 0 || index >= state.length) return;

    final sessionState = ref.read(sessionProvider);

    if (sessionState.isHost) {
      // Host updates locally and broadcasts
      state = state.copyWith(currentIndex: index);
      _broadcastQueueUpdate(QueueUpdateReason.skipped);

      // Load the song at the new index
      final currentSong = state.currentSong;
      if (currentSong != null) {
        debugPrint('[QueueProvider] Playing at index $index: ${currentSong.videoId}');
        ref.read(playerProvider.notifier).loadVideo(currentSong.videoId, title: currentSong.title);
      }
    } else {
      // Guest sends command to host
      debugPrint('[QueueProvider] Guest requesting playAtIndex: $index');
      ref.read(sessionProvider.notifier).client?.sendCommand('playAtIndex', index);
    }
  }

  void clearQueue() {
    state = const MusicQueue();
    _broadcastQueueUpdate(QueueUpdateReason.cleared);
  }

  void updateQueue(MusicQueue queue) {
    state = queue;
  }

  void _broadcastQueueUpdate(QueueUpdateReason reason) {
    final sessionState = ref.read(sessionProvider);
    if (sessionState.isHost && sessionState.isConnected) {
      ref.read(sessionProvider.notifier).server?.updateQueue(state, reason);
    }
  }

  /// Request title for a specific videoId (lazy loading for queue items)
  void requestTitleForVideoId(String videoId) {
    debugPrint('[QueueProvider] Requesting title for videoId: $videoId');
    ref.read(playerProvider.notifier).requestVideoTitle(videoId);
  }
}
