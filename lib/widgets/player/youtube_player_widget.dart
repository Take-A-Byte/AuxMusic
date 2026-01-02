import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../../providers/queue_provider.dart';

class YouTubePlayerWidget extends ConsumerStatefulWidget {
  const YouTubePlayerWidget({super.key});

  @override
  ConsumerState<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends ConsumerState<YouTubePlayerWidget> {
  late final WebViewController _controller;
  bool _isReady = false;
  bool _playerApiReady = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[YouTubePlayer] initState called - widget is mounting');
    _initWebView();
  }

  void _initWebView() {
    debugPrint('[YouTubePlayer] _initWebView called, creating WebViewController');

    // Create platform-specific params for Android
    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
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
            // JS is already inline in HTML, no need to inject
          },
          onWebResourceError: (error) {
            debugPrint('[YouTubePlayer] WebResource error: ${error.description}');
          },
        ),
      );

    // Enable media playback on Android
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      debugPrint('[YouTubePlayer] Android-specific: media playback gesture requirement disabled');
    }

    // Load HTML - don't spoof youtube.com as baseUrl, it causes playback errors
    _controller.loadHtmlString(_playerHtml);
    debugPrint('[YouTubePlayer] WebViewController created and HTML loading started');
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
      loadVideo(currentSong.videoId);
    }
  }

  void loadVideo(String videoId) {
    debugPrint('[YouTubePlayer] loadVideo called with: $videoId');
    if (videoId.startsWith('playlist:')) {
      final playlistId = videoId.substring(9);
      debugPrint('[YouTubePlayer] Loading playlist: $playlistId');
      _controller.runJavaScript("loadPlaylist('$playlistId')");
    } else {
      debugPrint('[YouTubePlayer] Loading video: $videoId');
      _controller.runJavaScript("loadVideo('$videoId')");
    }
  }

  void play() => _controller.runJavaScript('player?.playVideo()');
  void pause() => _controller.runJavaScript('player?.pauseVideo()');
  void seekTo(double seconds) => _controller.runJavaScript('player?.seekTo($seconds, true)');
  void setVolume(int volume) => _controller.runJavaScript('player?.setVolume($volume)');

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
        case 'seek':
          seekTo(command.value as double);
          break;
        case 'volume':
          setVolume(command.value as int);
          break;
        case 'load':
          loadVideo(command.value as String);
          break;
      }
    });

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_isReady)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  static const String _playerHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="player"></div>
  <script>
    // Override console.log to send to Flutter
    var originalLog = console.log;
    console.log = function() {
      var args = Array.prototype.slice.call(arguments);
      var message = args.map(function(arg) {
        return typeof arg === 'object' ? JSON.stringify(arg) : String(arg);
      }).join(' ');
      if (window.ConsoleLog) {
        ConsoleLog.postMessage(message);
      }
      originalLog.apply(console, arguments);
    };
    console.log('[HTML] Page loaded');
  </script>
  <script>
    var player;
    var stateInterval;

    // YouTube IFrame API ready callback - called automatically by YouTube
    // Using exact same playerVars as working player.html
    function onYouTubeIframeAPIReady() {
      console.log('[JS] onYouTubeIframeAPIReady called');
      player = new YT.Player('player', {
        height: '100%',
        width: '100%',
        playerVars: { autoplay: 0, rel: 0, modestbranding: 1 },
        events: {
          onReady: onPlayerReady,
          onStateChange: onPlayerStateChange
        }
      });
    }

    function onPlayerReady(event) {
      console.log('[JS] onPlayerReady');
      FlutterChannel.postMessage(JSON.stringify({ type: 'ready' }));
      stateInterval = setInterval(sendState, 1000);
    }

    function onPlayerStateChange(event) {
      console.log('[JS] onPlayerStateChange:', event.data);
      sendState();
      if (event.data === YT.PlayerState.ENDED) {
        FlutterChannel.postMessage(JSON.stringify({ type: 'videoEnded' }));
      }
    }

    function sendState() {
      if (!player || !player.getPlayerState) return;
      try {
        var state = player.getPlayerState();
        var videoData = player.getVideoData() || {};
        FlutterChannel.postMessage(JSON.stringify({
          type: 'stateChange',
          playerState: state,
          currentTime: player.getCurrentTime() || 0,
          duration: player.getDuration() || 0,
          volume: player.getVolume() || 100,
          videoId: videoData.video_id || '',
          title: videoData.title || ''
        }));
      } catch (e) {
        console.log('[JS] sendState error:', e.message);
      }
    }

    function loadVideo(videoId) {
      console.log('[JS] loadVideo:', videoId);
      if (player && player.loadVideoById) {
        player.loadVideoById(videoId);
        // loadVideoById auto-plays, but call playVideo just in case
        setTimeout(function() { player.playVideo && player.playVideo(); }, 500);
      }
    }

    function loadPlaylist(playlistId) {
      console.log('[JS] loadPlaylist:', playlistId);
      if (player && player.loadPlaylist) {
        player.loadPlaylist({ list: playlistId, listType: 'playlist', index: 0 });
        setTimeout(function() { player.playVideo && player.playVideo(); }, 500);
      }
    }
  </script>
  <script src="https://www.youtube.com/iframe_api"></script>
</body>
</html>
''';
}
