import 'package:flutter/material.dart';

class StudentProfile extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentProfile({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(student['name'] ?? 'Student Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email: ${student['email'] ?? 'No email'}',
              style: const TextStyle(fontSize: 16),
            ),
            // Add more student details here as needed
          ],
        ),
      ),
    );
  }
}
