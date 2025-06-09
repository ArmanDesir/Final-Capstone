import 'package:flutter/material.dart';

class ExerciseDetails extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const ExerciseDetails({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise['title'] ?? 'Exercise Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions: ${exercise['instructions'] ?? 'No instructions'}',
              style: const TextStyle(fontSize: 16),
            ),
            // Add more exercise details here as needed
          ],
        ),
      ),
    );
  }
}
