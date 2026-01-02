import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/youtube_utils.dart';
import '../../providers/session_provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/player/playback_controls.dart';
import '../../widgets/queue/queue_list.dart';
import '../home/home_screen.dart';

class GuestControllerScreen extends ConsumerWidget {
  const GuestControllerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final playerState = ref.watch(playerProvider);
    final queue = ref.watch(queueProvider);
    final currentSong = queue.currentSong;

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionState.session?.hostName ?? 'Party'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(context, ref),
        ),
        actions: [
          // Connection indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: sessionState.isConnected ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  sessionState.isConnected ? 'Connected' : 'Reconnecting...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Now Playing Card
          _buildNowPlayingCard(context, currentSong, playerState),
          // Playback Controls
          const PlaybackControls(),
          // Queue Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Queue (${queue.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddSongSheet(context, ref),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Song'),
                ),
              ],
            ),
          ),
          // Queue List
          Expanded(
            child: QueueList(isHost: false),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlayingCard(BuildContext context, dynamic currentSong, dynamic playerState) {
    if (currentSong == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.music_note, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No song playing',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a song to the queue!',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: YouTubeUtils.getThumbnailUrl(currentSong.videoId),
              width: 120,
              height: 90,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 120,
                height: 90,
                color: AppColors.surface,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 120,
                height: 90,
                color: AppColors.surface,
                child: const Icon(Icons.music_note, color: AppColors.textSecondary),
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentSong.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Added by ${currentSong.addedByName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSongSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Song',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Paste YouTube URL or video ID',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final input = controller.text.trim();
                  if (input.isNotEmpty) {
                    ref.read(queueProvider.notifier).addSongFromUrl(input);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add to Queue'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Party?'),
        content: const Text('You can rejoin anytime by scanning the QR code again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(sessionProvider.notifier).disconnect();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
