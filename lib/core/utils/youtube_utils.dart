class YouTubeUtils {
  static final _videoIdPatterns = [
    RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})'),
    RegExp(r'^([a-zA-Z0-9_-]{11})$'),
  ];

  static final _playlistIdPatterns = [
    RegExp(r'[?&]list=([a-zA-Z0-9_-]+)'),
    RegExp(r'^(PL|RD|UU|LL|FL)[a-zA-Z0-9_-]+$'),
  ];

  static String? extractVideoId(String input) {
    input = input.trim();
    for (final pattern in _videoIdPatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  static String? extractPlaylistId(String input) {
    input = input.trim();
    for (final pattern in _playlistIdPatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  static String getThumbnailUrl(String videoId, {ThumbnailQuality quality = ThumbnailQuality.medium}) {
    switch (quality) {
      case ThumbnailQuality.default_:
        return 'https://img.youtube.com/vi/$videoId/default.jpg';
      case ThumbnailQuality.medium:
        return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
      case ThumbnailQuality.high:
        return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      case ThumbnailQuality.standard:
        return 'https://img.youtube.com/vi/$videoId/sddefault.jpg';
      case ThumbnailQuality.maxRes:
        return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    }
  }

  static String getEmbedUrl(String videoId, {bool autoplay = false}) {
    final params = <String, String>{
      'enablejsapi': '1',
      'rel': '0',
      'modestbranding': '1',
      'playsinline': '1',
    };
    if (autoplay) params['autoplay'] = '1';

    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://www.youtube.com/embed/$videoId?$queryString';
  }

  static bool isValidVideoId(String? id) {
    if (id == null) return false;
    return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  }

  static bool isValidPlaylistId(String? id) {
    if (id == null) return false;
    return RegExp(r'^(PL|RD|UU|LL|FL)[a-zA-Z0-9_-]+$').hasMatch(id);
  }
}

enum ThumbnailQuality { default_, medium, high, standard, maxRes }
