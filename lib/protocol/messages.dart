import 'dart:convert';
import '../models/models.dart';

abstract class WSMessage {
  String get type;
  Map<String, dynamic> toJson();

  String encode() => jsonEncode(toJson());

  static WSMessage? decode(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'register':
          return RegisterMessage.fromJson(json);
        case 'register_ack':
          return RegisterAckMessage.fromJson(json);
        case 'state':
          return StateUpdateMessage.fromJson(json);
        case 'command':
          return CommandMessage.fromJson(json);
        case 'queue_add':
          return QueueAddMessage.fromJson(json);
        case 'queue_remove':
          return QueueRemoveMessage.fromJson(json);
        case 'queue_update':
          return QueueUpdateMessage.fromJson(json);
        case 'user_joined':
          return UserJoinedMessage.fromJson(json);
        case 'user_left':
          return UserLeftMessage.fromJson(json);
        case 'error':
          return ErrorMessage.fromJson(json);
        case 'server_shutdown':
          return ServerShutdownMessage.fromJson(json);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }
}

// === REGISTRATION ===

class RegisterMessage extends WSMessage {
  @override
  final String type = 'register';
  final UserRole role;
  final String userName;

  RegisterMessage({required this.role, required this.userName});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'role': role.name,
        'userName': userName,
      };

  factory RegisterMessage.fromJson(Map<String, dynamic> json) {
    return RegisterMessage(
      role: UserRole.values.firstWhere((r) => r.name == json['role']),
      userName: json['userName'] as String,
    );
  }
}

class RegisterAckMessage extends WSMessage {
  @override
  final String type = 'register_ack';
  final String sessionId;
  final String assignedUserId;
  final MusicQueue currentQueue;
  final PlayerState currentState;
  final List<User> connectedUsers;

  RegisterAckMessage({
    required this.sessionId,
    required this.assignedUserId,
    required this.currentQueue,
    required this.currentState,
    required this.connectedUsers,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'sessionId': sessionId,
        'assignedUserId': assignedUserId,
        'currentQueue': currentQueue.toJson(),
        'currentState': currentState.toJson(),
        'connectedUsers': connectedUsers.map((u) => u.toJson()).toList(),
      };

  factory RegisterAckMessage.fromJson(Map<String, dynamic> json) {
    return RegisterAckMessage(
      sessionId: json['sessionId'] as String,
      assignedUserId: json['assignedUserId'] as String,
      currentQueue: MusicQueue.fromJson(json['currentQueue'] as Map<String, dynamic>),
      currentState: PlayerState.fromJson(json['currentState'] as Map<String, dynamic>),
      connectedUsers: (json['connectedUsers'] as List)
          .map((u) => User.fromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }
}

// === PLAYER STATE ===

class StateUpdateMessage extends WSMessage {
  @override
  final String type = 'state';
  final PlayerState state;
  final MusicQueue queue;

  StateUpdateMessage({required this.state, required this.queue});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'state': state.toJson(),
        'queue': queue.toJson(),
      };

  factory StateUpdateMessage.fromJson(Map<String, dynamic> json) {
    return StateUpdateMessage(
      state: PlayerState.fromJson(json['state'] as Map<String, dynamic>),
      queue: MusicQueue.fromJson(json['queue'] as Map<String, dynamic>),
    );
  }
}

// === COMMANDS ===

class CommandMessage extends WSMessage {
  @override
  final String type = 'command';
  final String action;
  final dynamic value;

  CommandMessage({required this.action, this.value});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'action': action,
        'value': value,
      };

  factory CommandMessage.fromJson(Map<String, dynamic> json) {
    return CommandMessage(
      action: json['action'] as String,
      value: json['value'],
    );
  }

  // Factory constructors for common commands
  factory CommandMessage.play() => CommandMessage(action: 'play');
  factory CommandMessage.pause() => CommandMessage(action: 'pause');
  factory CommandMessage.stop() => CommandMessage(action: 'stop');
  factory CommandMessage.next() => CommandMessage(action: 'next');
  factory CommandMessage.prev() => CommandMessage(action: 'prev');
  factory CommandMessage.seek(double seconds) => CommandMessage(action: 'seek', value: seconds);
  factory CommandMessage.volume(int level) => CommandMessage(action: 'volume', value: level);
  factory CommandMessage.load(String videoId) => CommandMessage(action: 'load', value: videoId);
  factory CommandMessage.requestTitle(String videoId) => CommandMessage(action: 'requestTitle', value: videoId);
  factory CommandMessage.playAtIndex(int index) => CommandMessage(action: 'playAtIndex', value: index);
}

// === QUEUE OPERATIONS ===

class QueueAddMessage extends WSMessage {
  @override
  final String type = 'queue_add';
  final Song song;
  final int? insertAt;

  QueueAddMessage({required this.song, this.insertAt});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'song': song.toJson(),
        'insertAt': insertAt,
      };

  factory QueueAddMessage.fromJson(Map<String, dynamic> json) {
    return QueueAddMessage(
      song: Song.fromJson(json['song'] as Map<String, dynamic>),
      insertAt: json['insertAt'] as int?,
    );
  }
}

class QueueRemoveMessage extends WSMessage {
  @override
  final String type = 'queue_remove';
  final String songId;
  final String requesterId;

  QueueRemoveMessage({required this.songId, required this.requesterId});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'songId': songId,
        'requesterId': requesterId,
      };

  factory QueueRemoveMessage.fromJson(Map<String, dynamic> json) {
    return QueueRemoveMessage(
      songId: json['songId'] as String,
      requesterId: json['requesterId'] as String,
    );
  }
}

enum QueueUpdateReason { added, removed, reordered, cleared, songEnded, skipped }

class QueueUpdateMessage extends WSMessage {
  @override
  final String type = 'queue_update';
  final MusicQueue queue;
  final QueueUpdateReason reason;

  QueueUpdateMessage({required this.queue, required this.reason});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'queue': queue.toJson(),
        'reason': reason.name,
      };

  factory QueueUpdateMessage.fromJson(Map<String, dynamic> json) {
    return QueueUpdateMessage(
      queue: MusicQueue.fromJson(json['queue'] as Map<String, dynamic>),
      reason: QueueUpdateReason.values.firstWhere((r) => r.name == json['reason']),
    );
  }
}

// === USER EVENTS ===

class UserJoinedMessage extends WSMessage {
  @override
  final String type = 'user_joined';
  final User user;

  UserJoinedMessage({required this.user});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'user': user.toJson(),
      };

  factory UserJoinedMessage.fromJson(Map<String, dynamic> json) {
    return UserJoinedMessage(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserLeftMessage extends WSMessage {
  @override
  final String type = 'user_left';
  final String userId;

  UserLeftMessage({required this.userId});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'userId': userId,
      };

  factory UserLeftMessage.fromJson(Map<String, dynamic> json) {
    return UserLeftMessage(
      userId: json['userId'] as String,
    );
  }
}

// === ERROR ===

class ErrorMessage extends WSMessage {
  @override
  final String type = 'error';
  final String code;
  final String message;

  ErrorMessage({required this.code, required this.message});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'code': code,
        'message': message,
      };

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }
}

// === SERVER SHUTDOWN ===

class ServerShutdownMessage extends WSMessage {
  @override
  final String type = 'server_shutdown';
  final String reason;

  ServerShutdownMessage({this.reason = 'Host ended the party'});

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'reason': reason,
      };

  factory ServerShutdownMessage.fromJson(Map<String, dynamic> json) {
    return ServerShutdownMessage(
      reason: json['reason'] as String? ?? 'Host ended the party',
    );
  }
}
