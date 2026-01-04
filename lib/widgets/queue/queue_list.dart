import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/youtube_utils.dart';
import '../../models/models.dart';
import '../../providers/queue_provider.dart';

class QueueList extends ConsumerStatefulWidget {
  final bool isHost;
  final ScrollController? scrollController;

  const QueueList({
    super.key,
    required this.isHost,
    this.scrollController,
  });

  @override
  ConsumerState<QueueList> createState() => _QueueListState();
}

class _QueueListState extends ConsumerState<QueueList> {
  ScrollController? _internalScrollController;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
  }

  @override
  void dispose() {
    _internalScrollController?.dispose();
    super.dispose();
  }

  ScrollController _getScrollController() {
    return widget.scrollController ?? _internalScrollController!;
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider);

    if (queue.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _getScrollController(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: queue.songs.length,
      itemBuilder: (context, index) {
        final song = queue.songs[index];
        final isCurrentSong = index == queue.currentIndex;

        return _QueueItem(
          song: song,
          index: index,
          isHost: widget.isHost,
          isCurrent: isCurrentSong,
          onTap: () => ref.read(queueProvider.notifier).playAtIndex(index),
          onRemove: widget.isHost
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
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some songs to get started!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItem extends ConsumerStatefulWidget {
  final Song song;
  final int index;
  final bool isHost;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _QueueItem({
    required this.song,
    required this.index,
    required this.isHost,
    required this.isCurrent,
    required this.onTap,
    this.onRemove,
  });

  @override
  ConsumerState<_QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends ConsumerState<_QueueItem> {
  bool _hasRequestedTitle = false;

  @override
  void initState() {
    super.initState();
    _requestTitleIfNeeded();
  }

  @override
  void didUpdateWidget(_QueueItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the song changed, reset and check again
    if (oldWidget.song.videoId != widget.song.videoId) {
      _hasRequestedTitle = false;
      _requestTitleIfNeeded();
    }
  }

  void _requestTitleIfNeeded() {
    // Only request title if it's truly missing or a placeholder
    // Don't re-fetch if we already have a real title
    final needsTitle = widget.song.title.isEmpty ||
        widget.song.title == 'Loading...' ||
        widget.song.title == 'Unknown Title' ||
        widget.song.title == 'Unable to load title';

    if (needsTitle && !_hasRequestedTitle && widget.song.videoId.isNotEmpty) {
      _hasRequestedTitle = true;
      debugPrint('[QueueItem] Requesting title for videoId: ${widget.song.videoId}');
      // Request title from queue provider (which will call player provider)
      Future.microtask(() {
        ref.read(queueProvider.notifier).requestTitleForVideoId(widget.song.videoId);
      });
    } else if (!needsTitle) {
      debugPrint('[QueueItem] Skipping title fetch, already have: ${widget.song.title}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.song.id),
      direction: widget.isHost ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => widget.onRemove?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrent ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            border: widget.isCurrent
                ? Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 4,
                    ),
                  )
                : null,
          ),
          child: ListTile(
          onTap: widget.onTap,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.isCurrent ? 12 : 16,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: YouTubeUtils.getThumbnailUrl(widget.song.videoId),
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
          title: Row(
            children: [
              if (widget.isCurrent)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              Expanded(
                child: Text(
                  widget.song.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isCurrent ? AppColors.primary : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            'Added by ${widget.song.addedByName}',
            style: TextStyle(
              fontSize: 12,
              color: widget.isCurrent
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isHost && widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onRemove,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
