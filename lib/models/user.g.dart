// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  name: json['name'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  connectedAt: DateTime.parse(json['connectedAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'role': _$UserRoleEnumMap[instance.role]!,
  'connectedAt': instance.connectedAt.toIso8601String(),
  'isActive': instance.isActive,
};

const _$UserRoleEnumMap = {UserRole.host: 'host', UserRole.guest: 'guest'};
