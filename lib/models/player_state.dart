import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'player_state.g.dart';

enum PlayerStatus { idle, loading, playing, paused, buffering, ended, error }

@JsonSerializable()
class PlayerState extends Equatable {
  final bool isPlaying;
  final int currentPositionSeconds;
  final int totalDurationSeconds;
  final int volume;
  final String? currentVideoId;
  final String? currentTitle;
  final PlayerStatus status;

  const PlayerState({
    this.isPlaying = false,
    this.currentPositionSeconds = 0,
    this.totalDurationSeconds = 0,
    this.volume = 100,
    this.currentVideoId,
    this.currentTitle,
    this.status = PlayerStatus.idle,
  });

  static const initial = PlayerState();

  double get progress => totalDurationSeconds > 0
      ? currentPositionSeconds / totalDurationSeconds
      : 0.0;

  String get formattedCurrentTime {
    final minutes = currentPositionSeconds ~/ 60;
    final seconds = currentPositionSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final minutes = totalDurationSeconds ~/ 60;
    final seconds = totalDurationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  PlayerState copyWith({
    bool? isPlaying,
    int? currentPositionSeconds,
    int? totalDurationSeconds,
    int? volume,
    String? currentVideoId,
    String? currentTitle,
    PlayerStatus? status,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentPositionSeconds: currentPositionSeconds ?? this.currentPositionSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      volume: volume ?? this.volume,
      currentVideoId: currentVideoId ?? this.currentVideoId,
      currentTitle: currentTitle ?? this.currentTitle,
      status: status ?? this.status,
    );
  }

  factory PlayerState.fromJson(Map<String, dynamic> json) => _$PlayerStateFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerStateToJson(this);

  @override
  List<Object?> get props => [
        isPlaying,
        currentPositionSeconds,
        totalDurationSeconds,
        volume,
        currentVideoId,
        currentTitle,
        status,
      ];
}
