import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../../providers/queue_provider.dart';
import '../../services/server_service.dart';

class YouTubePlayerWidget extends ConsumerStatefulWidget {
  const YouTubePlayerWidget({super.key});

  @override
  ConsumerState<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends ConsumerState<YouTubePlayerWidget> {
  WebViewController? _controller;
  bool _isReady = false;
  bool _playerApiReady = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[YouTubePlayer] initState called - widget is mounting');
    _initWebView();
  }

  Future<void> _initWebView() async {
    debugPrint('[YouTubePlayer] _initWebView called, creating WebViewController');

    // Start the server if not already running
    final server = ServerService();
    if (!server.isRunning) {
      await server.start();
      debugPrint('[YouTubePlayer] Server started at http://${server.localIP}:${server.port}');
    }

    // Create platform-specific params for Android
    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _handleJsMessage,
      )
      ..addJavaScriptChannel(
        'ConsoleLog',
        onMessageReceived: (message) {
          debugPrint('[WebView Console] ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[YouTubePlayer] Page started loading: $url');
          },
          onPageFinished: (url) {
            debugPrint('[YouTubePlayer] Page finished loading: $url');
            setState(() => _isReady = true);
          },
          onWebResourceError: (error) {
            debugPrint('[YouTubePlayer] WebResource error: ${error.description}');
          },
        ),
      );

    // Enable media playback on Android
    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      // Enable background audio playback
      await androidController.setOnShowFileSelector((params) async => []);
      debugPrint('[YouTubePlayer] Android-specific: media playback gesture requirement disabled, background audio enabled');
    }

    // Load HTML from server URL (so location.host will be set correctly for WebSocket)
    final playerUrl = 'http://localhost:${server.port}/player.html';
    await controller.loadRequest(Uri.parse(playerUrl));
    debugPrint('[YouTubePlayer] Loading player from: $playerUrl');

    // Set the controller and trigger rebuild
    setState(() {
      _controller = controller;
    });
  }

  void _handleJsMessage(JavaScriptMessage message) {
    try {
      debugPrint('[YouTubePlayer] JS message received: ${message.message}');
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'stateChange') {
        ref.read(playerProvider.notifier).updateFromJs(data);
      } else if (type == 'videoEnded') {
        debugPrint('[YouTubePlayer] Video ended, playing next');
        ref.read(queueProvider.notifier).playNext();
      } else if (type == 'ready') {
        debugPrint('[YouTubePlayer] Player API ready!');
        _playerApiReady = true;
        _loadCurrentSong();
      } else if (type == 'videoInfo') {
        // HTML player processed a URL and is sending back video info
        debugPrint('[YouTubePlayer] Received videoInfo from HTML');
        ref.read(queueProvider.notifier).addSongFromPlayerResponse(data);
      } else if (type == 'playlistInfo') {
        // HTML player processed a playlist and is sending back multiple videos
        debugPrint('[YouTubePlayer] Received playlistInfo from HTML');
        final videos = data['videos'] as List<dynamic>?;
        if (videos != null) {
          for (final video in videos) {
            ref.read(queueProvider.notifier).addSongFromPlayerResponse(video as Map<String, dynamic>);
          }
        }
      } else if (type == 'videoInfoUpdate') {
        // HTML player is sending updated video info (e.g., real title for playlist video)
        debugPrint('[YouTubePlayer] Received videoInfoUpdate from HTML');
        ref.read(queueProvider.notifier).updateSongFromPlayerResponse(data);
      }
    } catch (e) {
      debugPrint('[YouTubePlayer] Error handling JS message: $e');
    }
  }

  void _loadCurrentSong() {
    final queue = ref.read(queueProvider);
    final currentSong = queue.currentSong;
    debugPrint('[YouTubePlayer] _loadCurrentSong called. currentSong: ${currentSong?.title}');
    if (currentSong != null) {
      loadVideo(currentSong.videoId, title: currentSong.title);
    }
  }

  void loadVideo(String input, {String? title}) {
    debugPrint('[YouTubePlayer] loadVideo called with: $input, title: $title');
    if (_controller == null || input.isEmpty) return;

    // Update player provider with title to avoid showing "Unknown Title"
    if (title != null && title.isNotEmpty) {
      ref.read(playerProvider.notifier).loadVideo(input, title: title);
    }

    // Execute JavaScript directly in the WebView
    final escapedInput = input.replaceAll("'", "\\'");
    _controller!.runJavaScript("loadVideo('$escapedInput')");
    debugPrint('[YouTubePlayer] Called JavaScript loadVideo with: $input');
  }

  void play() {
    _controller?.runJavaScript('if(player) player.playVideo()');
  }

  void pause() {
    _controller?.runJavaScript('if(player) player.pauseVideo()');
  }

  void stop() {
    _controller?.runJavaScript('if(player) player.stopVideo()');
  }

  void seekTo(double seconds) {
    _controller?.runJavaScript('if(player) player.seekTo($seconds, true)');
  }

  void setVolume(int volume) {
    _controller?.runJavaScript('if(player) player.setVolume($volume)');
  }

  void nextVideo() {
    _controller?.runJavaScript('if(player) player.nextVideo()');
  }

  void previousVideo() {
    _controller?.runJavaScript('if(player) player.previousVideo()');
  }

  void requestVideoTitle(String videoId) {
    debugPrint('[YouTubePlayer] Requesting title for videoId: $videoId');
    _controller?.runJavaScript('fetchVideoTitle("$videoId")');
  }

  @override
  void dispose() {
    debugPrint('[YouTubePlayer] dispose called - stopping server');
    // Stop the server when the player widget is disposed
    final server = ServerService();
    // Fire and forget - we can't await in dispose
    server.stop().catchError((e) {
      debugPrint('[YouTubePlayer] Error stopping server: $e');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[YouTubePlayer] build() called. _isReady=$_isReady, _playerApiReady=$_playerApiReady');

    // Listen to queue changes to load new videos
    ref.listen<int>(queueProvider.select((q) => q.currentIndex), (prev, next) {
      debugPrint('[YouTubePlayer] currentIndex changed: $prev -> $next, _playerApiReady=$_playerApiReady');
      if (prev != next && _playerApiReady) {
        _loadCurrentSong();
      }
    });

    // Also listen for when queue goes from empty to having songs
    ref.listen<int>(queueProvider.select((q) => q.length), (prev, next) {
      debugPrint('[YouTubePlayer] queue length changed: $prev -> $next, _playerApiReady=$_playerApiReady');
      if (prev == 0 && next > 0 && _playerApiReady) {
        _loadCurrentSong();
      }
    });

    // Listen to player commands
    ref.listen(playerCommandProvider, (_, command) {
      if (command == null) return;
      switch (command.action) {
        case 'play':
          play();
          break;
        case 'pause':
          pause();
          break;
        case 'stop':
          stop();
          break;
        case 'seek':
          seekTo(command.value as double);
          break;
        case 'volume':
          setVolume(command.value as int);
          break;
        case 'load':
          loadVideo(command.value as String);
          break;
        case 'next':
          nextVideo();
          break;
        case 'prev':
        case 'previous':
          previousVideo();
          break;
        case 'playAtIndex':
          final index = command.value as int;
          ref.read(queueProvider.notifier).playAtIndex(index);
          break;
        case 'requestTitle':
          requestVideoTitle(command.value as String);
          break;
      }
    });

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!),
          if (_controller == null || !_isReady)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
