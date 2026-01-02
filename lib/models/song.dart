import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'song.g.dart';

@JsonSerializable()
class Song extends Equatable {
  final String id;
  final String videoId;
  final String title;
  final String? artist;
  final String thumbnailUrl;
  final int durationSeconds;
  final String addedBy;
  final String addedByName;
  final DateTime addedAt;

  const Song({
    required this.id,
    required this.videoId,
    required this.title,
    this.artist,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.addedBy,
    required this.addedByName,
    required this.addedAt,
  });

  String get youtubeUrl => 'https://youtube.com/watch?v=$videoId';
  String get highResThumbnail => 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
  String get mediumThumbnail => 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);

  @override
  List<Object?> get props => [id, videoId, title, artist, thumbnailUrl, durationSeconds, addedBy, addedByName, addedAt];
}
