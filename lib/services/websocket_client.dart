import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';
import '../protocol/messages.dart';

class WebSocketClient {
  final String serverUrl;
  final void Function(WSMessage message) onMessage;
  final void Function()? onConnected;
  final void Function()? onDisconnected;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  WebSocketClient({
    required this.serverUrl,
    required this.onMessage,
    this.onConnected,
    this.onDisconnected,
  });

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      await _channel!.ready;

      _isConnected = true;
      onConnected?.call();

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );
    } catch (e) {
      _handleDisconnect();
      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;

    final message = WSMessage.decode(data);
    if (message != null) {
      onMessage(message);
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    onDisconnected?.call();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_shouldReconnect && !_isConnected) {
        connect();
      }
    });
  }

  Future<void> register(String userName, UserRole role) async {
    send(RegisterMessage(role: role, userName: userName));
  }

  void send(WSMessage message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message.encode());
    }
  }

  void sendCommand(String action, [dynamic value]) {
    send(CommandMessage(action: action, value: value));
  }

  void play() => sendCommand('play');
  void pause() => sendCommand('pause');
  void next() => sendCommand('next');
  void prev() => sendCommand('prev');
  void seek(double seconds) => sendCommand('seek', seconds);
  void setVolume(int level) => sendCommand('volume', level);
  void loadVideo(String videoId) => sendCommand('load', videoId);

  void addToQueue(Song song) {
    send(QueueAddMessage(song: song));
  }

  void removeFromQueue(String songId, String requesterId) {
    send(QueueRemoveMessage(songId: songId, requesterId: requesterId));
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}
