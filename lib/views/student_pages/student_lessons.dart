import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student_pages/lesson_details.dart';

class StudentLessonsPage extends StatelessWidget {
  final String classId;

  const StudentLessonsPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('lessons')
                .where('classId', isEqualTo: classId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No lessons found'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final lesson = snapshot.data!.docs[index];
              return ListTile(
                title: Text(lesson['title'] ?? 'Unknown'),
                subtitle: Text(lesson['description'] ?? 'No description'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => LessonDetails(
                            lesson: lesson.data() as Map<String, dynamic>,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
