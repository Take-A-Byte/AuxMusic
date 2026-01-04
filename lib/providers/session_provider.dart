import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/embedded_server.dart';
import '../services/websocket_client.dart';
import '../protocol/messages.dart';
import 'player_provider.dart';
import 'queue_provider.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});

class SessionState {
  final Session? session;
  final User? currentUser;
  final bool isHost;
  final bool isConnected;
  final String? error;
  final bool serverShutdown;
  final String? shutdownReason;

  const SessionState({
    this.session,
    this.currentUser,
    this.isHost = false,
    this.isConnected = false,
    this.error,
    this.serverShutdown = false,
    this.shutdownReason,
  });

  SessionState copyWith({
    Session? session,
    User? currentUser,
    bool? isHost,
    bool? isConnected,
    String? error,
    bool? serverShutdown,
    String? shutdownReason,
  }) {
    return SessionState(
      session: session ?? this.session,
      currentUser: currentUser ?? this.currentUser,
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      serverShutdown: serverShutdown ?? this.serverShutdown,
      shutdownReason: shutdownReason ?? this.shutdownReason,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref ref;
  EmbeddedServer? _server;
  WebSocketClient? _client;
  StreamSubscription? _serverMessagesSubscription;

  SessionNotifier(this.ref) : super(const SessionState());

  EmbeddedServer? get server => _server;
  WebSocketClient? get client => _client;

  Future<Session?> startHosting(String hostName) async {
    try {
      const uuid = Uuid();
      final hostId = uuid.v4();
      final sessionId = uuid.v4().substring(0, 8).toUpperCase();

      _server = EmbeddedServer();
      _server!.setHostId(hostId);
      final serverInfo = await _server!.start();

      // Listen to server messages and forward commands to player
      _serverMessagesSubscription = _server!.messages.listen((message) {
        if (message is CommandMessage) {
          // Forward guest commands to the host's player
          ref.read(playerCommandProvider.notifier).state = message;
        } else if (message is QueueUpdateMessage) {
          // Guest modified the queue (add/remove), sync local state without broadcasting
          ref.read(queueProvider.notifier).updateQueue(message.queue);
        } else if (message is UserJoinedMessage || message is UserLeftMessage) {
          // Update connected users list
          _updateConnectedUsers();
        }
      });

      final user = User(
        id: hostId,
        name: hostName,
        role: UserRole.host,
        connectedAt: DateTime.now(),
      );

      final session = Session(
        id: sessionId,
        hostId: hostId,
        hostName: hostName,
        serverIp: serverInfo.ip,
        serverPort: serverInfo.port,
        connectedUsers: [user], // Initialize with host
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        session: session,
        currentUser: user,
        isHost: true,
        isConnected: true,
      );

      return session;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> joinSession(Session session, String userName) async {
    try {
      const uuid = Uuid();
      final userId = uuid.v4();

      _client = WebSocketClient(
        serverUrl: session.connectionUrl,
        onMessage: _handleMessage,
        onConnected: () => state = state.copyWith(isConnected: true),
        onDisconnected: () => state = state.copyWith(isConnected: false),
      );

      await _client!.connect();
      await _client!.register(userName, UserRole.guest);

      final user = User(
        id: userId,
        name: userName,
        role: UserRole.guest,
        connectedAt: DateTime.now(),
      );

      state = state.copyWith(
        session: session,
        currentUser: user,
        isHost: false,
        isConnected: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void _handleMessage(WSMessage message) {
    // Handle incoming messages from server (for guests)
    if (message is RegisterAckMessage) {
      // Initial sync when joining
      ref.read(queueProvider.notifier).updateQueue(message.currentQueue);
      ref.read(playerProvider.notifier).updateState(message.currentState);
    } else if (message is StateUpdateMessage) {
      // Update player state from host
      ref.read(playerProvider.notifier).updateState(message.state);
      ref.read(queueProvider.notifier).updateQueue(message.queue);
    } else if (message is QueueUpdateMessage) {
      // Update queue from host
      ref.read(queueProvider.notifier).updateQueue(message.queue);
    } else if (message is ServerShutdownMessage) {
      // Host shut down the server
      state = state.copyWith(
        serverShutdown: true,
        shutdownReason: message.reason,
      );
    }
  }

  void _updateConnectedUsers() {
    if (_server == null || state.session == null) return;

    // Get updated list of connected users from server
    final updatedUsers = _server!.connectedUsers;

    // Create updated session with new connected users list
    final updatedSession = Session(
      id: state.session!.id,
      hostId: state.session!.hostId,
      hostName: state.session!.hostName,
      serverIp: state.session!.serverIp,
      serverPort: state.session!.serverPort,
      connectedUsers: updatedUsers,
      createdAt: state.session!.createdAt,
    );

    // Update state with new session
    state = state.copyWith(session: updatedSession);
  }

  Future<void> disconnect() async {
    await _serverMessagesSubscription?.cancel();
    _serverMessagesSubscription = null;
    await _server?.stop();
    _client?.disconnect();
    _server = null;
    _client = null;
    state = const SessionState();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
