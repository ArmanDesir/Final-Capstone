import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherQuizzes extends StatefulWidget {
  const TeacherQuizzes({super.key});

  @override
  State<TeacherQuizzes> createState() => _TeacherQuizzesState();
}

class _TeacherQuizzesState extends State<TeacherQuizzes> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List<DocumentSnapshot> quizzes = [];
  List<DocumentSnapshot> lessons = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Load lessons for the dropdown
        final lessonsQuery =
            await _firestore
                .collection('lessons')
                .where('teacherId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        // Load quizzes
        final quizzesQuery =
            await _firestore
                .collection('quizzes')
                .where('teacherId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        if (!mounted) return;
        setState(() {
          lessons = lessonsQuery.docs;
          quizzes = quizzesQuery.docs;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading data')));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addQuiz() async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    if (lessons.isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Please create a lesson first')),
      );
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    String? selectedLessonId = lessons.first.id;

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Quiz'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedLessonId,
                    decoration: const InputDecoration(
                      labelText: 'Select Lesson',
                    ),
                    items:
                        lessons.map((lesson) {
                          return DropdownMenuItem(
                            value: lesson.id,
                            child: Text(lesson['title']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      selectedLessonId = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Quiz Title',
                      hintText: 'Enter quiz title',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter quiz description',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      hintText: 'Enter quiz duration',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a quiz title'),
                      ),
                    );
                    return;
                  }

                  final duration = int.tryParse(durationController.text);
                  if (duration == null || duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid duration'),
                      ),
                    );
                    return;
                  }

                  final user = _auth.currentUser;
                  if (user != null && selectedLessonId != null) {
                    try {
                      await _firestore.collection('quizzes').add({
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'duration': duration,
                        'lessonId': selectedLessonId,
                        'teacherId': user.uid,
                        'createdAt': FieldValue.serverTimestamp(),
                        'questions': [], // Initialize empty questions array
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      debugPrint('Error adding quiz: $e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error adding quiz')),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _editQuiz(DocumentSnapshot quiz) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final titleController = TextEditingController(text: quiz['title']);
    final descriptionController = TextEditingController(
      text: quiz['description'],
    );
    final durationController = TextEditingController(
      text: quiz['duration'].toString(),
    );
    String selectedLessonId = quiz['lessonId'];

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Quiz'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedLessonId,
                    decoration: const InputDecoration(
                      labelText: 'Select Lesson',
                    ),
                    items:
                        lessons.map((lesson) {
                          return DropdownMenuItem(
                            value: lesson.id,
                            child: Text(lesson['title']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedLessonId = value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Quiz Title',
                      hintText: 'Enter quiz title',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter quiz description',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      hintText: 'Enter quiz duration',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a quiz title'),
                      ),
                    );
                    return;
                  }

                  final duration = int.tryParse(durationController.text);
                  if (duration == null || duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid duration'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _firestore.collection('quizzes').doc(quiz.id).update({
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'duration': duration,
                      'lessonId': selectedLessonId,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    debugPrint('Error updating quiz: $e');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error updating quiz')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteQuiz(String quizId) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Quiz'),
            content: const Text('Are you sure you want to delete this quiz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('quizzes').doc(quizId).delete();
        if (!dialogContext.mounted) return;
        _loadData();
      } catch (e) {
        debugPrint('Error deleting quiz: $e');
        if (!dialogContext.mounted) return;
        ScaffoldMessenger.of(
          dialogContext,
        ).showSnackBar(const SnackBar(content: Text('Error deleting quiz')));
      }
    }
  }

  Future<void> _manageQuestions(DocumentSnapshot quiz) async {
    final navigationContext = context;
    if (!navigationContext.mounted) return;

    Navigator.push(
      navigationContext,
      MaterialPageRoute(builder: (_) => QuizQuestions(quiz: quiz)),
    );
  }

  String _getLessonTitle(String lessonId) {
    try {
      final lesson = lessons.firstWhere((l) => l.id == lessonId);
      return lesson['title'] ?? 'Unknown Lesson';
    } catch (e) {
      return 'Unknown Lesson';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Quizzes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuiz,
        child: const Icon(Icons.add),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : quizzes.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.quiz, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No quizzes yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _addQuiz,
                      child: const Text('Add your first quiz'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: quizzes.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(quiz['title']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lesson: ${_getLessonTitle(quiz['lessonId'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            quiz['description'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Duration: ${quiz['duration']} minutes',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.question_answer),
                            onPressed: () => _manageQuestions(quiz),
                            tooltip: 'Manage Questions',
                          ),
                          PopupMenuButton(
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editQuiz(quiz);
                              } else if (value == 'delete') {
                                _deleteQuiz(quiz.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

// This is a placeholder for the QuizQuestions page
// You'll need to implement this separately
class QuizQuestions extends StatelessWidget {
  final DocumentSnapshot quiz;

  const QuizQuestions({super.key, required this.quiz});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Questions for ${quiz['title']}')),
      body: const Center(child: Text('Question management coming soon...')),
    );
  }
}
