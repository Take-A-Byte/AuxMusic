import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../../providers/queue_provider.dart';

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final queue = ref.watch(queueProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Seek Bar
          _buildSeekBar(ref, playerState),
          const SizedBox(height: 8),
          // Time Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                playerState.formattedCurrentTime,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                playerState.formattedDuration,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                onPressed: queue.currentIndex > 0
                    ? () => ref.read(queueProvider.notifier).playPrevious()
                    : null,
              ),
              // Rewind
              _buildControlButton(
                icon: Icons.replay_10_rounded,
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .seek(playerState.currentPositionSeconds - 10),
              ),
              // Play/Pause
              _buildPlayButton(ref, playerState.isPlaying),
              // Forward
              _buildControlButton(
                icon: Icons.forward_10_rounded,
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .seek(playerState.currentPositionSeconds + 10),
              ),
              // Next
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                onPressed: queue.currentIndex < queue.length - 1
                    ? () => ref.read(queueProvider.notifier).playNext()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Volume Slider
          _buildVolumeSlider(ref, playerState.volume),
        ],
      ),
    );
  }

  Widget _buildSeekBar(WidgetRef ref, dynamic playerState) {
    return SliderTheme(
      data: const SliderThemeData(
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: playerState.progress.clamp(0.0, 1.0),
        onChanged: (value) {
          final seconds = (value * playerState.totalDurationSeconds).toInt();
          ref.read(playerProvider.notifier).seek(seconds);
        },
        activeColor: AppColors.primary,
        inactiveColor: Colors.white24,
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    double size = 28,
  }) {
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      color: onPressed != null ? Colors.white : Colors.white30,
    );
  }

  Widget _buildPlayButton(WidgetRef ref, bool isPlaying) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 36,
        ),
        onPressed: () {
          if (isPlaying) {
            ref.read(playerProvider.notifier).pause();
          } else {
            ref.read(playerProvider.notifier).play();
          }
        },
        color: Colors.white,
      ),
    );
  }

  Widget _buildVolumeSlider(WidgetRef ref, int volume) {
    return Row(
      children: [
        Icon(
          volume == 0 ? Icons.volume_off : Icons.volume_up,
          size: 20,
          color: AppColors.textSecondary,
        ),
        Expanded(
          child: Slider(
            value: volume / 100,
            onChanged: (value) {
              ref.read(playerProvider.notifier).setVolume((value * 100).toInt());
            },
            activeColor: AppColors.textSecondary,
            inactiveColor: Colors.white12,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$volume%',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
