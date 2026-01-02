// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MusicQueue _$MusicQueueFromJson(Map<String, dynamic> json) => MusicQueue(
  songs:
      (json['songs'] as List<dynamic>?)
          ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  currentIndex: (json['currentIndex'] as num?)?.toInt() ?? -1,
  repeatMode:
      $enumDecodeNullable(_$QueueRepeatModeEnumMap, json['repeatMode']) ??
      QueueRepeatMode.off,
  shuffle: json['shuffle'] as bool? ?? false,
);

Map<String, dynamic> _$MusicQueueToJson(MusicQueue instance) =>
    <String, dynamic>{
      'songs': instance.songs.map((e) => e.toJson()).toList(),
      'currentIndex': instance.currentIndex,
      'repeatMode': _$QueueRepeatModeEnumMap[instance.repeatMode]!,
      'shuffle': instance.shuffle,
    };

const _$QueueRepeatModeEnumMap = {
  QueueRepeatMode.off: 'off',
  QueueRepeatMode.one: 'one',
  QueueRepeatMode.all: 'all',
};
