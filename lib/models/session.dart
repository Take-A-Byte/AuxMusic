import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'session.g.dart';

@JsonSerializable(explicitToJson: true)
class Session extends Equatable {
  final String id;
  final String hostId;
  final String hostName;
  final String serverIp;
  final int serverPort;
  final List<User> connectedUsers;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.serverIp,
    required this.serverPort,
    this.connectedUsers = const [],
    required this.createdAt,
  });

  String get connectionUrl => 'ws://$serverIp:$serverPort';
  String get displayUrl => '$serverIp:$serverPort';

  String get qrData => jsonEncode({
        'sessionId': id,
        'ip': serverIp,
        'port': serverPort,
        'hostName': hostName,
      });

  int get userCount => connectedUsers.length;

  Session copyWith({
    String? id,
    String? hostId,
    String? hostName,
    String? serverIp,
    int? serverPort,
    List<User>? connectedUsers,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      connectedUsers: connectedUsers ?? this.connectedUsers,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Session addUser(User user) {
    return copyWith(connectedUsers: [...connectedUsers, user]);
  }

  Session removeUser(String userId) {
    return copyWith(
      connectedUsers: connectedUsers.where((u) => u.id != userId).toList(),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
  Map<String, dynamic> toJson() => _$SessionToJson(this);

  static Session? fromQrData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      return Session(
        id: data['sessionId'] as String,
        hostId: '',
        hostName: data['hostName'] as String? ?? 'Host',
        serverIp: data['ip'] as String,
        serverPort: data['port'] as int,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object?> get props => [id, hostId, hostName, serverIp, serverPort, connectedUsers, createdAt];
}
