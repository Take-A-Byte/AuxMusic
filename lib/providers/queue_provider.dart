import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';
import '../core/utils/youtube_utils.dart';
import '../protocol/messages.dart';
import 'session_provider.dart';

final queueProvider = StateNotifierProvider<QueueNotifier, MusicQueue>((ref) {
  return QueueNotifier(ref);
});

class QueueNotifier extends StateNotifier<MusicQueue> {
  final Ref ref;
  static const _uuid = Uuid();

  QueueNotifier(this.ref) : super(const MusicQueue());

  Future<void> addSongFromUrl(String input) async {
    debugPrint('[QueueProvider] addSongFromUrl called with: $input');

    // Check if it's a playlist
    final playlistId = YouTubeUtils.extractPlaylistId(input);
    debugPrint('[QueueProvider] Extracted playlistId: $playlistId');
    if (playlistId != null) {
      await _loadPlaylist(playlistId);
      return;
    }

    // Single video
    final videoId = YouTubeUtils.extractVideoId(input);
    debugPrint('[QueueProvider] Extracted videoId: $videoId');
    if (videoId == null) {
      throw Exception('Invalid YouTube URL or video ID');
    }

    // Fetch video metadata
    final metadata = await _fetchVideoMetadata(videoId);

    final sessionState = ref.read(sessionProvider);
    final currentUser = sessionState.currentUser;

    final song = Song(
      id: _uuid.v4(),
      videoId: videoId,
      title: metadata['title'] ?? 'Unknown Title',
      artist: metadata['author_name'],
      thumbnailUrl: YouTubeUtils.getThumbnailUrl(videoId),
      durationSeconds: 0, // noembed doesn't provide duration
      addedBy: currentUser?.id ?? '',
      addedByName: currentUser?.name ?? 'Unknown',
      addedAt: DateTime.now(),
    );

    addSong(song);
  }

  Future<void> _loadPlaylist(String playlistId) async {
    final sessionState = ref.read(sessionProvider);
    final currentUser = sessionState.currentUser;

    // For now, we'll load the playlist directly in the player
    // The player will handle fetching all videos
    // We create a placeholder song to trigger playlist loading
    final song = Song(
      id: _uuid.v4(),
      videoId: 'playlist:$playlistId', // Special prefix to indicate playlist
      title: 'Loading playlist...',
      thumbnailUrl: '',
      durationSeconds: 0,
      addedBy: currentUser?.id ?? '',
      addedByName: currentUser?.name ?? 'Unknown',
      addedAt: DateTime.now(),
    );

    addSong(song);
  }

  Future<Map<String, dynamic>> _fetchVideoMetadata(String videoId) async {
    try {
      final url = 'https://noembed.com/embed?url=https://www.youtube.com/watch?v=$videoId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Ignore errors, return empty metadata
    }
    return {};
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
  }

  void playPrevious() {
    state = state.playPrevious();
    _broadcastQueueUpdate(QueueUpdateReason.skipped);
  }

  void playAtIndex(int index) {
    if (index >= 0 && index < state.length) {
      state = state.copyWith(currentIndex: index);
      _broadcastQueueUpdate(QueueUpdateReason.skipped);
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
      ref.read(sessionProvider.notifier).server?.updateQueue(state);
    }
  }
}
