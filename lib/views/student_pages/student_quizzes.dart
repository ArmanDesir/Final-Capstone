import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentQuizzes extends StatefulWidget {
  final String classId;

  const StudentQuizzes({super.key, required this.classId});

  @override
  State<StudentQuizzes> createState() => _StudentQuizzesState();
}

class _StudentQuizzesState extends State<StudentQuizzes> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<DocumentSnapshot> quizzes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      debugPrint('Loading quizzes for class: ${widget.classId}');
      final quizzesQuery =
          await _firestore
              .collection('quizzes')
              .where('classId', isEqualTo: widget.classId)
              .orderBy('createdAt', descending: true)
              .get();

      debugPrint('Quizzes loaded: ${quizzesQuery.docs.length}');

      if (!mounted) return;
      setState(() {
        quizzes = quizzesQuery.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading quizzes: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading quizzes: $e')));
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('StudentQuizzes: classId = ${widget.classId}');
    return Scaffold(
      appBar: AppBar(title: const Text('Quizzes')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : quizzes.isEmpty
              ? const Center(child: Text('No quizzes found'))
              : ListView.builder(
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  return ListTile(
                    title: Text(quiz['title'] ?? 'Unknown'),
                    subtitle: Text(quiz['description'] ?? 'No description'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => QuizDetails(
                                quiz: quiz.data() as Map<String, dynamic>,
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

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
              'Description: ${quiz['description'] ?? 'No description'}',
              style: const TextStyle(fontSize: 16),
            ),
            // Add more quiz details here as needed
          ],
        ),
      ),
    );
  }
}
