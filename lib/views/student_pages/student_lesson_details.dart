import 'package:flutter/material.dart';

class StudentLessonDetails extends StatelessWidget {
  final Map<String, dynamic> lesson;

  const StudentLessonDetails({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lesson['title'] ?? 'Lesson Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson['title'] ?? 'Untitled Lesson',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              lesson['description'] ?? 'No description available',
              style: const TextStyle(fontSize: 16),
            ),
            if (lesson['content'] != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Content:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(lesson['content'], style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
