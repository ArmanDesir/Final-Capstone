import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassDetails extends StatefulWidget {
  final DocumentSnapshot classDoc;

  const ClassDetails({super.key, required this.classDoc});

  @override
  State<ClassDetails> createState() => _ClassDetailsState();
}

class _ClassDetailsState extends State<ClassDetails> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String teacherName = '';
  List<Map<String, dynamic>> lessons = [];
  List<Map<String, dynamic>> exercises = [];
  List<Map<String, dynamic>> quizzes = [];

  @override
  void initState() {
    super.initState();
    _loadClassContent();
  }

  Future<void> _loadClassContent() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final classData = widget.classDoc.data() as Map<String, dynamic>;

      // Load teacher info
      final teacherDoc =
          await _firestore
              .collection('users')
              .doc(classData['teacherId'])
              .get();

      // Load lessons for this class
      final lessonsQuery =
          await _firestore
              .collection('lessons')
              .where('teacherId', isEqualTo: classData['teacherId'])
              .orderBy('createdAt', descending: true)
              .get();

      // Load exercises for this class
      final exercisesQuery =
          await _firestore
              .collection('exercises')
              .where('teacherId', isEqualTo: classData['teacherId'])
              .orderBy('createdAt', descending: true)
              .get();

      // Load quizzes for this class
      final quizzesQuery =
          await _firestore
              .collection('quizzes')
              .where('teacherId', isEqualTo: classData['teacherId'])
              .orderBy('createdAt', descending: true)
              .get();

      if (!mounted) return;
      setState(() {
        teacherName = teacherDoc.data()?['name'] ?? 'Unknown Teacher';
        lessons =
            lessonsQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
        exercises =
            exercisesQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
        quizzes =
            quizzesQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading class content: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classData = widget.classDoc.data() as Map<String, dynamic>;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(classData['name'] ?? 'Class Details'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Lessons'),
              Tab(text: 'Exercises'),
              Tab(text: 'Quizzes'),
            ],
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    // Overview Tab
                    SingleChildScrollView(
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
                          const SizedBox(height: 8),
                          Text(
                            'Teacher: $teacherName',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Description:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            classData['description'] ??
                                'No description available',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),

                    // Lessons Tab
                    lessons.isEmpty
                        ? const Center(child: Text('No lessons available'))
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: lessons.length,
                          itemBuilder: (context, index) {
                            final lesson = lessons[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  lesson['title'] ?? 'Untitled Lesson',
                                ),
                                subtitle: Text(
                                  lesson['description'] ?? 'No description',
                                ),
                                leading: const Icon(Icons.book),
                                onTap: () {
                                  // TODO: Navigate to lesson details
                                },
                              ),
                            );
                          },
                        ),

                    // Exercises Tab
                    exercises.isEmpty
                        ? const Center(child: Text('No exercises available'))
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  exercise['title'] ?? 'Untitled Exercise',
                                ),
                                subtitle: Text(
                                  exercise['description'] ?? 'No description',
                                ),
                                leading: const Icon(Icons.edit),
                                onTap: () {
                                  // TODO: Navigate to exercise details
                                },
                              ),
                            );
                          },
                        ),

                    // Quizzes Tab
                    quizzes.isEmpty
                        ? const Center(child: Text('No quizzes available'))
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: quizzes.length,
                          itemBuilder: (context, index) {
                            final quiz = quizzes[index];
                            return Card(
                              child: ListTile(
                                title: Text(quiz['title'] ?? 'Untitled Quiz'),
                                subtitle: Text(
                                  'Duration: ${quiz['duration']} minutes',
                                ),
                                leading: const Icon(Icons.quiz),
                                onTap: () {
                                  // TODO: Navigate to quiz details
                                },
                              ),
                            );
                          },
                        ),
                  ],
                ),
      ),
    );
  }
}
