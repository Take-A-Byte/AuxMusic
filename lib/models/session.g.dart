// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) => Session(
  id: json['id'] as String,
  hostId: json['hostId'] as String,
  hostName: json['hostName'] as String,
  serverIp: json['serverIp'] as String,
  serverPort: (json['serverPort'] as num).toInt(),
  connectedUsers:
      (json['connectedUsers'] as List<dynamic>?)
          ?.map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
  'id': instance.id,
  'hostId': instance.hostId,
  'hostName': instance.hostName,
  'serverIp': instance.serverIp,
  'serverPort': instance.serverPort,
  'connectedUsers': instance.connectedUsers.map((e) => e.toJson()).toList(),
  'createdAt': instance.createdAt.toIso8601String(),
};
