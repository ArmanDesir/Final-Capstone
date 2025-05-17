import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherLessons extends StatefulWidget {
  const TeacherLessons({super.key});

  @override
  State<TeacherLessons> createState() => _TeacherLessonsState();
}

class _TeacherLessonsState extends State<TeacherLessons> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List<DocumentSnapshot> lessons = [];

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot =
            await _firestore
                .collection('lessons')
                .where('teacherId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        if (!mounted) return;
        setState(() {
          lessons = querySnapshot.docs;
        });
      }
    } catch (e) {
      debugPrint('Error loading lessons: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading lessons')));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addLesson() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Lesson'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    hintText: 'Enter lesson title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter lesson description',
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
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a lesson title'),
                      ),
                    );
                    return;
                  }

                  final user = _auth.currentUser;
                  if (user != null) {
                    try {
                      await _firestore.collection('lessons').add({
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'teacherId': user.uid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _loadLessons();
                    } catch (e) {
                      debugPrint('Error adding lesson: $e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error adding lesson')),
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

  Future<void> _editLesson(DocumentSnapshot lesson) async {
    final titleController = TextEditingController(text: lesson['title']);
    final descriptionController = TextEditingController(
      text: lesson['description'],
    );
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Lesson'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    hintText: 'Enter lesson title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter lesson description',
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
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a lesson title'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _firestore
                        .collection('lessons')
                        .doc(lesson.id)
                        .update({
                          'title': titleController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadLessons();
                  } catch (e) {
                    debugPrint('Error updating lesson: $e');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error updating lesson')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteLesson(String lessonId) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Lesson'),
            content: const Text('Are you sure you want to delete this lesson?'),
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
        await _firestore.collection('lessons').doc(lessonId).delete();
        _loadLessons();
      } catch (e) {
        debugPrint('Error deleting lesson: $e');
        if (!dialogContext.mounted) return;
        ScaffoldMessenger.of(
          dialogContext,
        ).showSnackBar(const SnackBar(content: Text('Error deleting lesson')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Lessons'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLessons),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLesson,
        child: const Icon(Icons.add),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : lessons.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No lessons yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _addLesson,
                      child: const Text('Add your first lesson'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: lessons.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(lesson['title']),
                      subtitle: Text(
                        lesson['description'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                            _editLesson(lesson);
                          } else if (value == 'delete') {
                            _deleteLesson(lesson.id);
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
