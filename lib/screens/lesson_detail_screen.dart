import 'package:flutter/material.dart';
import 'package:offline_first_app/screens/LessonQuizScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/content.dart';

class LessonDetailScreen extends StatelessWidget {
  final Content content;
  const LessonDetailScreen({super.key, required this.content});

  Future<void> _openFile(BuildContext context) async {
    if (content.fileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No file attached.")),
      );
      return;
    }

    final Uri url = Uri.parse(content.fileUrl!);

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open ${content.fileName}")),
      );
    }
  }

  String? _getYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      if (url.contains('/shorts/')) {
        return url.split('/shorts/').last.split('?').first;
      }

      if (url.contains('/watch')) {
        final uri = Uri.parse(url);
        return uri.queryParameters['v'];
      }
    } catch (e) {
    }

    return YoutubePlayer.convertUrlToId(url);
  }

  @override
  Widget build(BuildContext context) {
    final youtubeId = _getYoutubeId(content.youtubeUrl);
    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(content.description ?? ''),
            const SizedBox(height: 16),

            if (content.fileUrl != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text("Open Attached File"),
                  subtitle: Text(content.fileName ?? "Lesson document"),
                  onTap: () => _openFile(context),
                ),
              ),
            const SizedBox(height: 16),

            if (youtubeId != null && youtubeId.isNotEmpty) ...[
              Text(
                "Video Lesson",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              YoutubePlayer(
                controller: YoutubePlayerController(
                  initialVideoId: youtubeId,
                  flags: const YoutubePlayerFlags(autoPlay: false),
                ),
                showVideoProgressIndicator: true,
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LessonQuizzesScreen(
                      lessonId: content.id,
                      classroomId: content.classroomId,
                      userId: Supabase.instance.client.auth.currentUser!.id,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.quiz),
              label: const Text("Take Quiz"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
