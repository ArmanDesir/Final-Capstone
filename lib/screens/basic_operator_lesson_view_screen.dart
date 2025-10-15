import 'package:flutter/material.dart';
import 'package:offline_first_app/models/basic_operator_lesson.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';

class BasicOperatorLessonViewScreen extends StatelessWidget {
  final BasicOperatorLesson lesson;
  const BasicOperatorLessonViewScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lesson.youtubeUrl != null && lesson.youtubeUrl!.isNotEmpty)
              _buildYoutubePreview(context),

            if (lesson.fileUrl != null && lesson.fileUrl!.isNotEmpty)
              _buildFileSection(context),

            const SizedBox(height: 16),
            Text(
              lesson.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (lesson.description != null && lesson.description!.isNotEmpty)
              Text(
                lesson.description!,
                style: const TextStyle(fontSize: 16),
              )
            else
              const Text('No description provided.'),
            const SizedBox(height: 24),
            _buildMetadata(context),
          ],
        ),
      ),
    );
  }

  Widget _buildYoutubePreview(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(lesson.youtubeUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open YouTube link')),
          );
        }
      },
      child: Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black12,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Icon(Icons.play_circle_fill, color: Colors.red, size: 64),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSection(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Open Lesson File'),
          onPressed: () async {
            final url = Uri.parse(lesson.fileUrl!);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open file link')),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMetadata(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Operator: ${lesson.operator}',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        if (lesson.createdAt != null)
          Text(
            'Created: ${lesson.createdAt!.toLocal()}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
      ],
    );
  }
}
