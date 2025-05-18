import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'teacher_student_list.dart';

class TeacherClassList extends StatefulWidget {
  const TeacherClassList({super.key});

  @override
  State<TeacherClassList> createState() => _TeacherClassListState();
}

class _TeacherClassListState extends State<TeacherClassList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List<DocumentSnapshot> classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if (!mounted) return;
    debugPrint('Starting to load classes...');
    setState(() => isLoading = true);
    try {
      final user = _auth.currentUser;
      debugPrint('Current user: ${user?.uid}');
      if (user != null) {
        debugPrint('Fetching classes for user: ${user.uid}');
        final querySnapshot =
            await _firestore
                .collection('classes')
                .where('teacherId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        debugPrint('Classes fetched: ${querySnapshot.docs.length}');
        if (!mounted) return;
        setState(() {
          classes = querySnapshot.docs;
          isLoading = false;
        });
      } else {
        debugPrint('No user found');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login again')));
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading classes: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<void> _addClass() async {
    if (!mounted) return;
    debugPrint('Starting to add class...');

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final classCode = _generateClassCode();
    debugPrint('Generated class code: $classCode');

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'Enter class name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter class description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Class Code: $classCode',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a class name')),
                  );
                  return;
                }

                try {
                  debugPrint(
                    'Attempting to add class with name: ${nameController.text}',
                  );
                  final user = _auth.currentUser;
                  if (user == null) {
                    debugPrint('No authenticated user found');
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('User not authenticated')),
                    );
                    return;
                  }

                  debugPrint('Adding class to Firestore...');
                  final docRef = await _firestore.collection('classes').add({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'classCode': classCode,
                    'teacherId': user.uid,
                    'students': [],
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  debugPrint('Class added successfully with ID: ${docRef.id}');
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  debugPrint('Reloading classes...');
                  await _loadClasses();
                } catch (e, stackTrace) {
                  debugPrint('Error adding class: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Error adding class: ${e.toString()}'),
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editClass(DocumentSnapshot classDoc) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final nameController = TextEditingController(text: classDoc['name']);
    final descriptionController = TextEditingController(
      text: classDoc['description'],
    );

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Class'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class Name',
                    hintText: 'Enter class name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter class description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Class Code: ${classDoc['classCode']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a class name'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _firestore
                        .collection('classes')
                        .doc(classDoc.id)
                        .update({
                          'name': nameController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadClasses();
                  } catch (e) {
                    debugPrint('Error updating class: $e');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error updating class')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteClass(String classId) async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Class'),
            content: const Text('Are you sure you want to delete this class?'),
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
        await _firestore.collection('classes').doc(classId).delete();
        if (!dialogContext.mounted) return;
        _loadClasses();
      } catch (e) {
        debugPrint('Error deleting class: $e');
        if (!dialogContext.mounted) return;
        ScaffoldMessenger.of(
          dialogContext,
        ).showSnackBar(const SnackBar(content: Text('Error deleting class')));
      }
    }
  }

  Future<void> _viewStudents(DocumentSnapshot classDoc) async {
    // Navigate to student list page for this class
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassStudents(classDoc: classDoc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadClasses),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClass,
        child: const Icon(Icons.add),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : classes.isEmpty
              ? const Center(
                child: Text('No classes yet. Tap + to add a class.'),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final doc = classes[index];
                  final classData = doc.data() as Map<String, dynamic>;
                  final students = classData['students'] as List? ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(classData['name'] ?? 'Unnamed Class'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(classData['description'] ?? 'No description'),
                          const SizedBox(height: 4),
                          Text(
                            'Class Code: ${classData['classCode'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${students.length} student${students.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.people),
                            onPressed: () => _viewStudents(doc),
                            tooltip: 'View Students',
                          ),
                          PopupMenuButton<String>(
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
                                _editClass(doc);
                              } else if (value == 'delete') {
                                _deleteClass(doc.id);
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

// Replace the placeholder ClassStudents widget at the bottom of the file
class ClassStudents extends StatelessWidget {
  final DocumentSnapshot classDoc;

  const ClassStudents({super.key, required this.classDoc});

  @override
  Widget build(BuildContext context) {
    final classData = classDoc.data() as Map<String, dynamic>;
    return TeacherStudentList(
      classId: classDoc.id,
      className: 'Students in ${classData['name']}',
    );
  }
}
