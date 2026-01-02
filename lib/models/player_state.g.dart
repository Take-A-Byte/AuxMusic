// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerState _$PlayerStateFromJson(Map<String, dynamic> json) => PlayerState(
  isPlaying: json['isPlaying'] as bool? ?? false,
  currentPositionSeconds:
      (json['currentPositionSeconds'] as num?)?.toInt() ?? 0,
  totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
  volume: (json['volume'] as num?)?.toInt() ?? 100,
  currentVideoId: json['currentVideoId'] as String?,
  currentTitle: json['currentTitle'] as String?,
  status:
      $enumDecodeNullable(_$PlayerStatusEnumMap, json['status']) ??
      PlayerStatus.idle,
);

Map<String, dynamic> _$PlayerStateToJson(PlayerState instance) =>
    <String, dynamic>{
      'isPlaying': instance.isPlaying,
      'currentPositionSeconds': instance.currentPositionSeconds,
      'totalDurationSeconds': instance.totalDurationSeconds,
      'volume': instance.volume,
      'currentVideoId': instance.currentVideoId,
      'currentTitle': instance.currentTitle,
      'status': _$PlayerStatusEnumMap[instance.status]!,
    };

const _$PlayerStatusEnumMap = {
  PlayerStatus.idle: 'idle',
  PlayerStatus.loading: 'loading',
  PlayerStatus.playing: 'playing',
  PlayerStatus.paused: 'paused',
  PlayerStatus.buffering: 'buffering',
  PlayerStatus.ended: 'ended',
  PlayerStatus.error: 'error',
};
