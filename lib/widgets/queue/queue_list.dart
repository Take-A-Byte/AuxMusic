import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/youtube_utils.dart';
import '../../models/models.dart';
import '../../providers/queue_provider.dart';

class QueueList extends ConsumerWidget {
  final bool isHost;

  const QueueList({super.key, required this.isHost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);

    if (queue.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: queue.upcomingSongs.length,
      itemBuilder: (context, index) {
        final song = queue.upcomingSongs[index];
        final actualIndex = queue.currentIndex + 1 + index;

        return _QueueItem(
          song: song,
          index: actualIndex,
          isHost: isHost,
          onTap: () => ref.read(queueProvider.notifier).playAtIndex(actualIndex),
          onRemove: isHost
              ? () => ref.read(queueProvider.notifier).removeSong(song.id)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some songs to get started!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final Song song;
  final int index;
  final bool isHost;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _QueueItem({
    required this.song,
    required this.index,
    required this.isHost,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(song.id),
      direction: isHost ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onRemove?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: YouTubeUtils.getThumbnailUrl(song.videoId),
            width: 64,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 64,
              height: 48,
              color: AppColors.surface,
            ),
            errorWidget: (_, __, ___) => Container(
              width: 64,
              height: 48,
              color: AppColors.surface,
              child: const Icon(Icons.music_note, size: 20),
            ),
          ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Added by ${song.addedByName}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHost && onRemove != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onRemove,
                color: Colors.white38,
              ),
          ],
        ),
      ),
    );
  }
}
