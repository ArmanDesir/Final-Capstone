import 'package:flutter/material.dart';

class LessonDetails extends StatelessWidget {
  final Map<String, dynamic> lesson;

  const LessonDetails({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lesson['title'] ?? 'Lesson Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description: ${lesson['description'] ?? 'No description'}',
              style: const TextStyle(fontSize: 16),
            ),
            // Add more lesson details here as needed
          ],
        ),
      ),
    );
  }
}
