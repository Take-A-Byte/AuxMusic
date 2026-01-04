import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/models.dart';
import '../protocol/messages.dart';

class ServerInfo {
  final String ip;
  final int port;

  ServerInfo({required this.ip, required this.port});
}

class ConnectedClient {
  final WebSocketChannel channel;
  final String id;
  final String name;
  final UserRole role;
  final DateTime connectedAt;

  ConnectedClient({
    required this.channel,
    required this.id,
    required this.name,
    required this.role,
    required this.connectedAt,
  });

  User toUser() => User(
        id: id,
        name: name,
        role: role,
        connectedAt: connectedAt,
      );
}

class EmbeddedServer {
  HttpServer? _server;
  final Map<WebSocketChannel, ConnectedClient> _clients = {};
  final _messageController = StreamController<WSMessage>.broadcast();

  MusicQueue _queue = const MusicQueue();
  PlayerState _playerState = const PlayerState();
  String? _hostId;

  Stream<WSMessage> get messages => _messageController.stream;
  MusicQueue get queue => _queue;
  PlayerState get playerState => _playerState;
  List<User> get connectedUsers => _clients.values.map((c) => c.toUser()).toList();

  void setHostId(String hostId) => _hostId = hostId;

  Future<ServerInfo> start({int port = 3000}) async {
    final handler = webSocketHandler(_handleWebSocket);

    _server = await shelf_io.serve(handler, '0.0.0.0', port);

    final ip = await _getLocalIp();

    return ServerInfo(ip: ip, port: port);
  }

  Future<String> _getLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null) return wifiIP;
    } catch (_) {}

    // Fallback: try to get IP from interfaces
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}

    return 'localhost';
  }

  void _handleWebSocket(WebSocketChannel channel) {
    channel.stream.listen(
      (data) => _handleMessage(channel, data as String),
      onDone: () => _handleDisconnect(channel),
      onError: (_) => _handleDisconnect(channel),
    );
  }

  void _handleMessage(WebSocketChannel channel, String data) {
    final message = WSMessage.decode(data);
    if (message == null) return;

    if (message is RegisterMessage) {
      _handleRegister(channel, message);
    } else if (message is CommandMessage) {
      _handleCommand(message);
      // Forward commands to host's player
      _messageController.add(message);
    } else if (message is QueueAddMessage) {
      _handleQueueAdd(message);
      // Emit queue update to host (not the add message, to avoid duplicate broadcast)
      _messageController.add(QueueUpdateMessage(queue: _queue, reason: QueueUpdateReason.added));
    } else if (message is QueueRemoveMessage) {
      _handleQueueRemove(message);
      // Emit queue update to host (not the remove message, to avoid duplicate broadcast)
      _messageController.add(QueueUpdateMessage(queue: _queue, reason: QueueUpdateReason.removed));
    }
  }

  void _handleRegister(WebSocketChannel channel, RegisterMessage message) {
    final client = ConnectedClient(
      channel: channel,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: message.userName,
      role: message.role,
      connectedAt: DateTime.now(),
    );

    _clients[channel] = client;

    // Send ack to new client
    final ack = RegisterAckMessage(
      sessionId: '',
      assignedUserId: client.id,
      currentQueue: _queue,
      currentState: _playerState,
      connectedUsers: connectedUsers,
    );
    channel.sink.add(ack.encode());

    // Notify others about new user
    final userJoinedMsg = UserJoinedMessage(user: client.toUser());
    _broadcast(userJoinedMsg, exclude: channel);

    // Notify host about new user
    _messageController.add(userJoinedMsg);
  }

  void _handleCommand(CommandMessage message) {
    // Commands are handled by the host's player
    // This just broadcasts to ensure state sync
    _messageController.add(message);
  }

  void _handleQueueAdd(QueueAddMessage message) {
    _queue = _queue.addSong(message.song);
    _broadcastQueueUpdate(QueueUpdateReason.added);
  }

  void _handleQueueRemove(QueueRemoveMessage message) {
    // Only host can remove songs
    if (message.requesterId != _hostId) {
      final client = _clients.values.firstWhere(
        (c) => c.id == message.requesterId,
        orElse: () => throw Exception('Client not found'),
      );
      client.channel.sink.add(ErrorMessage(
        code: 'PERMISSION_DENIED',
        message: 'Only the host can remove songs',
      ).encode());
      return;
    }

    _queue = _queue.removeSong(message.songId);
    _broadcastQueueUpdate(QueueUpdateReason.removed);
  }

  void _handleDisconnect(WebSocketChannel channel) {
    final client = _clients.remove(channel);
    if (client != null) {
      final userLeftMsg = UserLeftMessage(userId: client.id);
      _broadcast(userLeftMsg);

      // Notify host about user leaving
      _messageController.add(userLeftMsg);
    }
  }

  void updatePlayerState(PlayerState state) {
    _playerState = state;
    _broadcastState();
  }

  void updateQueue(MusicQueue queue, QueueUpdateReason reason) {
    _queue = queue;
    _broadcastQueueUpdate(reason);
  }

  void _broadcastState() {
    _broadcast(StateUpdateMessage(state: _playerState, queue: _queue));
  }

  void _broadcastQueueUpdate(QueueUpdateReason reason) {
    _broadcast(QueueUpdateMessage(queue: _queue, reason: reason));
  }

  void _broadcast(WSMessage message, {WebSocketChannel? exclude}) {
    final encoded = message.encode();
    for (final entry in _clients.entries) {
      if (entry.key != exclude) {
        entry.key.sink.add(encoded);
      }
    }
  }

  Future<void> stop() async {
    // Notify all clients that server is shutting down
    _broadcast(ServerShutdownMessage(reason: 'Host ended the party'));

    // Give clients a moment to receive the shutdown message
    await Future.delayed(const Duration(milliseconds: 500));

    // Close all client connections
    for (final channel in _clients.keys) {
      await channel.sink.close();
    }
    _clients.clear();

    // Close the server
    await _server?.close();
    _server = null;
    await _messageController.close();
  }
}
