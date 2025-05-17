import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherStudentList extends StatefulWidget {
  const TeacherStudentList({super.key});

  @override
  State<TeacherStudentList> createState() => _TeacherStudentListState();
}

class _TeacherStudentListState extends State<TeacherStudentList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List<DocumentSnapshot> classes = [];
  Map<String, DocumentSnapshot> students = {};
  String? selectedClassId;

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
        // Load all classes
        final classesQuery =
            await _firestore
                .collection('classes')
                .where('teacherId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        // Load all students from these classes
        final Map<String, DocumentSnapshot> studentsMap = {};
        for (var classDoc in classesQuery.docs) {
          final studentIds = (classDoc['students'] as List?) ?? [];
          for (var studentId in studentIds) {
            if (!studentsMap.containsKey(studentId)) {
              try {
                if (!mounted) return;
                final studentDoc =
                    await _firestore.collection('users').doc(studentId).get();
                if (studentDoc.exists) {
                  studentsMap[studentId] = studentDoc;
                }
              } catch (e) {
                debugPrint('Error loading student $studentId: $e');
              }
            }
          }
        }

        if (!mounted) return;
        setState(() {
          classes = classesQuery.docs;
          students = studentsMap;
          selectedClassId = classes.isNotEmpty ? classes.first.id : null;
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

  Future<void> _viewStudentProfile(
    DocumentSnapshot student,
    BuildContext context,
  ) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(student['name']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(student['email']),
                ),
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: Text(
                    'Student ID: ${student['studentId'] ?? 'Not set'}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.class_),
                  title: Text(
                    'Classes: ${classes.where((c) => (c['students'] as List?)?.contains(student.id) ?? false).length}',
                  ),
                ),
                const Divider(),
                const Text(
                  'Enrolled Classes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...classes
                    .where(
                      (c) =>
                          (c['students'] as List?)?.contains(student.id) ??
                          false,
                    )
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          '• ${c['name']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  List<DocumentSnapshot> _getFilteredStudents() {
    if (selectedClassId == null) {
      return students.values.toList();
    }

    final selectedClass = classes.firstWhere((c) => c.id == selectedClassId);
    final studentIds = (selectedClass['students'] as List?) ?? [];
    return studentIds
        .map((id) => students[id])
        .whereType<DocumentSnapshot>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student List'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : students.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No students yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Students will appear here when they join your classes',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String?>(
                      value: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Class',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Classes'),
                        ),
                        ...classes.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c['name']),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedClassId = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _getFilteredStudents().length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final student = _getFilteredStudents()[index];
                        final enrolledClasses =
                            classes
                                .where(
                                  (c) =>
                                      (c['students'] as List?)?.contains(
                                        student.id,
                                      ) ??
                                      false,
                                )
                                .toList();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                (student['name'] ?? 'S')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                              ),
                            ),
                            title: Text(student['name']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student['email']),
                                Text(
                                  'Enrolled in ${enrolledClasses.length} class${enrolledClasses.length == 1 ? '' : 'es'}',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed:
                                  () => _viewStudentProfile(student, context),
                              tooltip: 'View Profile',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
