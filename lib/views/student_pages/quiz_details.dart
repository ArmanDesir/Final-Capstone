import 'package:flutter/material.dart';

class QuizDetails extends StatelessWidget {
  final Map<String, dynamic> quiz;

  const QuizDetails({super.key, required this.quiz});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(quiz['title'] ?? 'Quiz Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duration: ${quiz['duration'] ?? 'N/A'} minutes',
              style: const TextStyle(fontSize: 16),
            ),
            // Add more quiz details here as needed
          ],
        ),
      ),
    );
  }
}
