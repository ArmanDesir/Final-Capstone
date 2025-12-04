
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubeUtils {

  static String? extractVideoId(String url) {
    if (url.isEmpty) return null;

    try {

      url = url.trim();

      if (url.contains('youtu.be/')) {
        final parts = url.split('youtu.be/');
        if (parts.length > 1) {
          final videoIdPart = parts[1].split('?').first.split('&').first.split('/').first;
          if (videoIdPart.isNotEmpty) return videoIdPart;
        }
      }

      if (url.contains('watch?v=') || url.contains('watch?v=')) {
        final uri = Uri.parse(url);
        final videoId = uri.queryParameters['v'];
        if (videoId != null && videoId.isNotEmpty) return videoId;
      }

      if (url.contains('/embed/')) {
        final parts = url.split('/embed/');
        if (parts.length > 1) {
          final videoId = parts[1].split('?').first.split('&').first;
          if (videoId.isNotEmpty) return videoId;
        }
      }

      if (url.contains('/shorts/')) {
        final parts = url.split('/shorts/');
        if (parts.length > 1) {
          final videoId = parts[1].split('?').first.split('&').first;
          if (videoId.isNotEmpty) return videoId;
        }
      }

      try {
        final videoId = YoutubePlayer.convertUrlToId(url);
        if (videoId != null && videoId.isNotEmpty) return videoId;
      } catch (_) {}

      if (url.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url)) {
        return url;
      }

      return null;
    } catch (e) {
      print('Error extracting YouTube video ID: $e');
      return null;
    }
  }

  static String? normalizeUrl(String url) {
    final videoId = extractVideoId(url);
    if (videoId == null) return null;
    return 'https://www.youtube.com/watch?v=$videoId';
  }
}

