import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

enum UserRole { host, guest }

@JsonSerializable()
class User extends Equatable {
  final String id;
  final String name;
  final UserRole role;
  final DateTime connectedAt;
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    required this.role,
    required this.connectedAt,
    this.isActive = true,
  });

  bool get isHost => role == UserRole.host;
  bool get isGuest => role == UserRole.guest;

  User copyWith({
    String? id,
    String? name,
    UserRole? role,
    DateTime? connectedAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      connectedAt: connectedAt ?? this.connectedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, name, role, connectedAt, isActive];
}
