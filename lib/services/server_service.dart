import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal();

  HttpServer? _server;
  final Set<WebSocket> _players = {};
  final Set<WebSocket> _controllers = {};
  bool _isStarting = false;
  bool _isStopping = false;

  bool get isRunning => _server != null;
  int get port => 8080; // Use different port from EmbeddedServer (3000)

  String? _localIP;
  String? get localIP => _localIP;

  String? _playerHtml;
  String? _controllerHtml;

  Future<void> loadHtmlAssets() async {
    _playerHtml = await rootBundle.loadString('assets/html/youtube_player.html');
    // Load controller HTML if you have one
    // _controllerHtml = await rootBundle.loadString('assets/html/controller.html');
  }

  void setHtmlContent({required String playerHtml, required String controllerHtml}) {
    _playerHtml = playerHtml;
    _controllerHtml = controllerHtml;
  }

  Future<void> start() async {
    // Wait for any ongoing stop operation to complete
    if (_isStopping) {
      print('[ServerService] Waiting for server to finish stopping...');
      while (_isStopping) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Check if server is already running or starting
    if (_server != null) {
      print('[ServerService] Server already running at http://$_localIP:$port');
      return;
    }

    if (_isStarting) {
      print('[ServerService] Server is already starting, waiting...');
      // Wait for the server to finish starting
      while (_isStarting && _server == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isStarting = true;

    try {
      // Load HTML assets if not already loaded
      if (_playerHtml == null) {
        await loadHtmlAssets();
      }

      _localIP = await _getLocalIP();

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true, // Allow multiple binds to the same port
      );
      print('[ServerService] Server started at http://$_localIP:$port');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleConnection(socket);
        } else {
          _handleHttpRequest(request);
        }
      });
    } finally {
      _isStarting = false;
    }
  }

  void _handleHttpRequest(HttpRequest request) {
    final path = request.uri.path;
    print('[ServerService] HTTP request: $path');

    if (path == '/player.html' || path == '/player' || path == '/') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_playerHtml ?? 'Player not loaded')
        ..close();
    } else if (path == '/controller.html' || path == '/controller') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_controllerHtml ?? 'Controller not loaded')
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('YT Control Server Running')
        ..close();
    }
  }

  void _handleConnection(WebSocket socket) {
    print('[ServerService] WebSocket connection established');

    socket.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          if (type == 'register') {
            final role = msg['role'] as String?;
            print('[ServerService] Client registered as: $role');
            if (role == 'player') {
              _players.add(socket);
            } else if (role == 'controller') {
              _controllers.add(socket);
            }
            return;
          }

          // Forward commands to players
          if (type == 'command') {
            print('[ServerService] Forwarding command to ${_players.length} player(s)');
            final message = jsonEncode(msg);
            for (final player in _players) {
              if (player.readyState == WebSocket.open) {
                player.add(message);
              }
            }
          }

          // Forward state to controllers
          if (type == 'state') {
            final message = jsonEncode(msg);
            for (final controller in _controllers) {
              if (controller.readyState == WebSocket.open) {
                controller.add(message);
              }
            }
          }
        } catch (e) {
          print('[ServerService] Error handling message: $e');
        }
      },
      onDone: () {
        print('[ServerService] WebSocket connection closed');
        _players.remove(socket);
        _controllers.remove(socket);
      },
      onError: (error) {
        print('[ServerService] WebSocket error: $error');
        _players.remove(socket);
        _controllers.remove(socket);
      },
    );
  }

  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('[ServerService] Error getting local IP: $e');
    }
    return 'localhost';
  }

  /// Send a command to all connected players
  void sendCommandToPlayers(Map<String, dynamic> command) {
    final message = jsonEncode(command);
    print('[ServerService] Broadcasting to ${_players.length} players: $message');

    for (final player in _players) {
      if (player.readyState == WebSocket.open) {
        player.add(message);
      }
    }
  }

  /// Send a message to all connected controllers
  void sendToControllers(Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    print('[ServerService] Sending to ${_controllers.length} controllers: $encoded');

    for (final controller in _controllers) {
      if (controller.readyState == WebSocket.open) {
        controller.add(encoded);
      }
    }
  }

  Future<void> stop() async {
    if (_server == null && !_isStarting) {
      print('[ServerService] Server already stopped');
      return;
    }

    if (_isStopping) {
      print('[ServerService] Server is already stopping, waiting...');
      while (_isStopping) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isStopping = true;
    _isStarting = false;

    try {
      print('[ServerService] Stopping server...');

      // Close all WebSocket connections
      for (final socket in [..._players, ..._controllers]) {
        await socket.close();
      }
      _players.clear();
      _controllers.clear();

      // Close the HTTP server
      await _server?.close(force: true);
      _server = null;

      print('[ServerService] Server stopped');
    } finally {
      _isStopping = false;
    }
  }
}
