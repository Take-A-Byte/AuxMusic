import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'song.dart';

part 'queue.g.dart';

enum QueueRepeatMode { off, one, all }

@JsonSerializable(explicitToJson: true)
class MusicQueue extends Equatable {
  final List<Song> songs;
  final int currentIndex;
  final QueueRepeatMode repeatMode;
  final bool shuffle;

  const MusicQueue({
    this.songs = const [],
    this.currentIndex = -1,
    this.repeatMode = QueueRepeatMode.off,
    this.shuffle = false,
  });

  static const empty = MusicQueue();

  Song? get currentSong =>
      currentIndex >= 0 && currentIndex < songs.length ? songs[currentIndex] : null;

  Song? get nextSong =>
      currentIndex + 1 < songs.length ? songs[currentIndex + 1] : null;

  Song? get previousSong => currentIndex > 0 ? songs[currentIndex - 1] : null;

  List<Song> get upcomingSongs =>
      currentIndex + 1 < songs.length ? songs.sublist(currentIndex + 1) : [];

  int get length => songs.length;
  bool get isEmpty => songs.isEmpty;
  bool get isNotEmpty => songs.isNotEmpty;

  MusicQueue copyWith({
    List<Song>? songs,
    int? currentIndex,
    QueueRepeatMode? repeatMode,
    bool? shuffle,
  }) {
    return MusicQueue(
      songs: songs ?? this.songs,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffle: shuffle ?? this.shuffle,
    );
  }

  MusicQueue addSong(Song song) {
    return copyWith(
      songs: [...songs, song],
      currentIndex: currentIndex == -1 ? 0 : currentIndex,
    );
  }

  MusicQueue removeSong(String songId) {
    final index = songs.indexWhere((s) => s.id == songId);
    if (index == -1) return this;

    final newSongs = [...songs]..removeAt(index);
    var newIndex = currentIndex;

    if (index < currentIndex) {
      newIndex--;
    } else if (index == currentIndex && newSongs.isNotEmpty) {
      newIndex = newIndex.clamp(0, newSongs.length - 1);
    } else if (newSongs.isEmpty) {
      newIndex = -1;
    }

    return copyWith(songs: newSongs, currentIndex: newIndex);
  }

  MusicQueue playNext() {
    if (currentIndex + 1 < songs.length) {
      return copyWith(currentIndex: currentIndex + 1);
    } else if (repeatMode == QueueRepeatMode.all && songs.isNotEmpty) {
      return copyWith(currentIndex: 0);
    }
    return this;
  }

  MusicQueue playPrevious() {
    if (currentIndex > 0) {
      return copyWith(currentIndex: currentIndex - 1);
    } else if (repeatMode == QueueRepeatMode.all && songs.isNotEmpty) {
      return copyWith(currentIndex: songs.length - 1);
    }
    return this;
  }

  factory MusicQueue.fromJson(Map<String, dynamic> json) => _$MusicQueueFromJson(json);
  Map<String, dynamic> toJson() => _$MusicQueueToJson(this);

  @override
  List<Object?> get props => [songs, currentIndex, repeatMode, shuffle];
}
