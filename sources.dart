import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core.dart';

class VideoSource {
  final Map<String, String> streams;
  final String? download;
  final bool demo;
  const VideoSource({required this.streams, this.download, this.demo = false});
}

/// Vercel Cloud Extractor API Call (থার্ড-পার্টি লিংক প্রসেস করার জন্য)
Future<String> getDirectVideoUrl(String rawUrl) async {
  if (rawUrl.isEmpty) return rawUrl;
  final apiUri = Uri.parse('https://cheetah-bd.vercel.app/api/get-link?url=${Uri.encodeComponent(rawUrl)}');
  try {
    final res = await http.get(apiUri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true && data['direct_url'] != null) {
        return data['direct_url'];
      }
    }
  } catch (_) {}
  return rawUrl;
}

/// ফুল অটোমেটিক সোর্স জেনারেটর (TMDB ID দিয়ে অটো এমবেড লিংক তৈরি হবে)
VideoSource sourceFor(Movie m) {
  final autoEmbedUrl = 'https://vidsrc.to/embed/movie/${m.id}';
  
  return VideoSource(
    streams: {
      'Auto': autoEmbedUrl,
    },
    download: autoEmbedUrl,
    demo: false,
  );
}
