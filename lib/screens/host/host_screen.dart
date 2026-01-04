import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../providers/queue_provider.dart';
import '../../services/server_service.dart';
import '../../widgets/player/youtube_player_widget.dart';
import '../../widgets/player/playback_controls.dart';
import '../../widgets/queue/queue_list.dart';
import '../home/home_screen.dart';

class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key});

  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen> {
  bool _showQR = false;
  bool _isStopping = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(session?.id ?? 'Hosting'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmExit,
          ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${session?.userCount ?? 0}'),
              child: const Icon(Icons.people_outline),
            ),
            onPressed: _showUsers,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => setState(() => _showQR = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // YouTube Player
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: YouTubePlayerWidget(),
              ),
              // Now Playing Info
              _buildNowPlaying(),
              // Playback Controls
              const PlaybackControls(),
              // Queue Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final queue = ref.watch(queueProvider);
                        return Text(
                          'Queue (${queue.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    TextButton.icon(
                      onPressed: _showAddSongSheet,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Song'),
                    ),
                  ],
                ),
              ),
              // Queue
              Expanded(
                child: ClipRect(
                  child: QueueList(isHost: true),
                ),
              ),
            ],
          ),
          // QR Code Overlay
          if (_showQR) _buildQROverlay(session?.qrData ?? ''),
          // Stopping Overlay
          if (_isStopping)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Stopping server...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildNowPlaying() {
    final queue = ref.watch(queueProvider);
    final currentSong = queue.currentSong;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            currentSong?.title ?? 'No song playing',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (currentSong != null)
            Text(
              'Added by ${currentSong.addedByName}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQROverlay(String qrData) {
    final session = ref.watch(sessionProvider).session;

    return GestureDetector(
      onTap: () => setState(() => _showQR = false),
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan to Join',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: qrData,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Or connect manually:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session?.displayUrl ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => setState(() => _showQR = false),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUsers() {
    final session = ref.read(sessionProvider).session;
    final users = session?.connectedUsers.where((u) => u.isGuest).toList() ?? [];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connected (${users.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (users.isEmpty)
              const Text(
                'No guests yet. Share the QR code!',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...users.map((user) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.card,
                      child: Text(user.name[0].toUpperCase()),
                    ),
                    title: Text(user.name),
                    subtitle: const Text('Guest'),
                  )),
          ],
        ),
      ),
    );
  }

  void _showAddSongSheet() {
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
                'Add Song or Playlist',
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
                  hintText: 'Paste YouTube URL, video ID, or playlist URL',
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

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Party?'),
        content: const Text('This will disconnect all guests and stop the music.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _handleExit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('End Party'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExit() async {
    // Show stopping overlay
    setState(() => _isStopping = true);

    try {
      // Clear the queue
      ref.read(queueProvider.notifier).clearQueue();

      // Disconnect session (stops EmbeddedServer)
      await ref.read(sessionProvider.notifier).disconnect();

      // Stop ServerService
      final server = ServerService();
      await server.stop();

      // Navigate back
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[HostScreen] Error during exit: $e');
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }
}
