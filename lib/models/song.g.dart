// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Song _$SongFromJson(Map<String, dynamic> json) => Song(
  id: json['id'] as String,
  videoId: json['videoId'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String,
  durationSeconds: (json['durationSeconds'] as num).toInt(),
  addedBy: json['addedBy'] as String,
  addedByName: json['addedByName'] as String,
  addedAt: DateTime.parse(json['addedAt'] as String),
);

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
  'id': instance.id,
  'videoId': instance.videoId,
  'title': instance.title,
  'artist': instance.artist,
  'thumbnailUrl': instance.thumbnailUrl,
  'durationSeconds': instance.durationSeconds,
  'addedBy': instance.addedBy,
  'addedByName': instance.addedByName,
  'addedAt': instance.addedAt.toIso8601String(),
};
