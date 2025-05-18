import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_lesson_details.dart';

class StudentClassDetails extends StatelessWidget {
  final DocumentSnapshot classDoc;
  final _firestore = FirebaseFirestore.instance;

  StudentClassDetails({super.key, required this.classDoc});

  Future<void> _navigateToLessons(BuildContext context) async {
    try {
      final classData = classDoc.data() as Map<String, dynamic>;
      final lessons =
          await _firestore
              .collection('lessons')
              .where('teacherId', isEqualTo: classData['teacherId'])
              .orderBy('createdAt', descending: true)
              .get();

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        builder:
            (context) => ListView.builder(
              itemCount: lessons.docs.length,
              itemBuilder: (context, index) {
                final lesson = lessons.docs[index].data();
                return ListTile(
                  title: Text(lesson['title'] ?? 'Untitled Lesson'),
                  subtitle: Text(lesson['description'] ?? 'No description'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => StudentLessonDetails(lesson: lesson),
                      ),
                    );
                  },
                );
              },
            ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading lessons: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final classData = classDoc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text(classData['name'] ?? 'Class Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Code: ${classData['classCode']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    classData['description'] ?? 'No description available',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Lessons'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _navigateToLessons(context),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Exercises'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to exercises
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: const Text('Quizzes'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to quizzes
            },
          ),
        ],
      ),
    );
  }
}
