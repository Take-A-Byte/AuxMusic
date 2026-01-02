import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/embedded_server.dart';
import '../services/websocket_client.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});

class SessionState {
  final Session? session;
  final User? currentUser;
  final bool isHost;
  final bool isConnected;
  final String? error;

  const SessionState({
    this.session,
    this.currentUser,
    this.isHost = false,
    this.isConnected = false,
    this.error,
  });

  SessionState copyWith({
    Session? session,
    User? currentUser,
    bool? isHost,
    bool? isConnected,
    String? error,
  }) {
    return SessionState(
      session: session ?? this.session,
      currentUser: currentUser ?? this.currentUser,
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref ref;
  EmbeddedServer? _server;
  WebSocketClient? _client;

  SessionNotifier(this.ref) : super(const SessionState());

  EmbeddedServer? get server => _server;
  WebSocketClient? get client => _client;

  Future<Session?> startHosting(String hostName) async {
    try {
      const uuid = Uuid();
      final hostId = uuid.v4();
      final sessionId = uuid.v4().substring(0, 8).toUpperCase();

      _server = EmbeddedServer();
      final serverInfo = await _server!.start();

      final session = Session(
        id: sessionId,
        hostId: hostId,
        hostName: hostName,
        serverIp: serverInfo.ip,
        serverPort: serverInfo.port,
        createdAt: DateTime.now(),
      );

      final user = User(
        id: hostId,
        name: hostName,
        role: UserRole.host,
        connectedAt: DateTime.now(),
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

  void _handleMessage(dynamic message) {
    // Handle incoming messages from server
    // This will be expanded to update queue, player state, etc.
  }

  Future<void> disconnect() async {
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
