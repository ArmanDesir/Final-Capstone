import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherExercises extends StatefulWidget {
  const TeacherExercises({super.key});

  @override
  State<TeacherExercises> createState() => _TeacherExercisesState();
}

class _TeacherExercisesState extends State<TeacherExercises> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List<DocumentSnapshot> exercises = [];
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

        // Load exercises
        final exercisesQuery =
            await _firestore
                .collection('exercises')
                .where('teacherId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        if (!mounted) return;
        setState(() {
          lessons = lessonsQuery.docs;
          exercises = exercisesQuery.docs;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        _showSnackBar('Error loading data');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addExercise() async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    if (lessons.isEmpty) {
      _showSnackBar('Please create a lesson first');
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedLessonId = lessons.first.id;

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Exercise'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedLessonId,
                  decoration: const InputDecoration(labelText: 'Select Lesson'),
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
                    labelText: 'Exercise Title',
                    hintText: 'Enter exercise title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    hintText: 'Enter exercise instructions',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    _showSnackBar('Please enter an exercise title');
                    return;
                  }

                  final user = _auth.currentUser;
                  if (user != null && selectedLessonId != null) {
                    try {
                      await _firestore.collection('exercises').add({
                        'title': titleController.text.trim(),
                        'instructions': descriptionController.text.trim(),
                        'lessonId': selectedLessonId,
                        'teacherId': user.uid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      debugPrint('Error adding exercise: $e');
                      if (!context.mounted) return;
                      _showSnackBar('Error adding exercise');
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _editExercise(DocumentSnapshot exercise) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final titleController = TextEditingController(text: exercise['title']);
    final instructionsController = TextEditingController(
      text: exercise['instructions'],
    );
    String selectedLessonId = exercise['lessonId'];

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Exercise'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedLessonId,
                  decoration: const InputDecoration(labelText: 'Select Lesson'),
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
                    labelText: 'Exercise Title',
                    hintText: 'Enter exercise title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    hintText: 'Enter exercise instructions',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    _showSnackBar('Please enter an exercise title');
                    return;
                  }

                  try {
                    await _firestore
                        .collection('exercises')
                        .doc(exercise.id)
                        .update({
                          'title': titleController.text.trim(),
                          'instructions': instructionsController.text.trim(),
                          'lessonId': selectedLessonId,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    debugPrint('Error updating exercise: $e');
                    if (!context.mounted) return;
                    _showSnackBar('Error updating exercise');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteExercise(String exerciseId) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Exercise'),
            content: const Text(
              'Are you sure you want to delete this exercise?',
            ),
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
        await _firestore.collection('exercises').doc(exerciseId).delete();
        if (!dialogContext.mounted) return;
        _loadData();
      } catch (e) {
        debugPrint('Error deleting exercise: $e');
        if (!dialogContext.mounted) return;
        _showSnackBar('Error deleting exercise');
      }
    }
  }

  String _getLessonTitle(String lessonId) {
    final lesson = lessons.cast<DocumentSnapshot?>().firstWhere(
      (l) => l?.id == lessonId,
      orElse: () => null,
    );
    return lesson?['title'] ?? 'Unknown Lesson';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Exercises'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExercise,
        child: const Icon(Icons.add),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : exercises.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assignment, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No exercises yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _addExercise,
                      child: const Text('Add your first exercise'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: exercises.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(exercise['title']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lesson: ${_getLessonTitle(exercise['lessonId'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exercise['instructions'] ?? 'No instructions',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
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
                            _editExercise(exercise);
                          } else if (value == 'delete') {
                            _deleteExercise(exercise.id);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
