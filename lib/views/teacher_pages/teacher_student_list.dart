import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherStudentList extends StatefulWidget {
  final String? classId; // Optional class ID for filtering
  final String? className; // Optional class name for title

  const TeacherStudentList({super.key, this.classId, this.className});

  @override
  State<TeacherStudentList> createState() => _TeacherStudentListState();
}

class _TeacherStudentListState extends State<TeacherStudentList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  List<DocumentSnapshot> classes = [];
  Map<String, DocumentSnapshot> students = {};
  String? selectedClassId;

  @override
  void initState() {
    super.initState();
    // If a specific class is provided, use it as the selected class
    selectedClassId = widget.classId;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      debugPrint('Loading data for teacher: ${user?.uid}');

      if (user != null) {
        // Load classes query
        Query classesQuery = _firestore
            .collection('classes')
            .where('teacherId', isEqualTo: user.uid);

        // If specific class ID is provided, filter for that class only
        if (widget.classId != null) {
          debugPrint('Loading specific class: ${widget.classId}');
          classesQuery = classesQuery.where(
            FieldPath.documentId,
            isEqualTo: widget.classId,
          );
        } else {
          classesQuery = classesQuery.orderBy('createdAt', descending: true);
        }

        // Execute the query
        final classesSnapshot = await classesQuery.get();
        debugPrint('Found ${classesSnapshot.docs.length} classes');

        if (classesSnapshot.docs.isEmpty) {
          debugPrint('No classes found');
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage =
                widget.classId != null ? 'Class not found' : 'No classes found';
          });
          return;
        }

        // Load all students from these classes
        final Map<String, DocumentSnapshot> studentsMap = {};
        for (var classDoc in classesSnapshot.docs) {
          final studentIds = (classDoc['students'] as List?) ?? [];
          debugPrint('Class ${classDoc.id} has ${studentIds.length} students');

          for (var studentId in studentIds) {
            if (!studentsMap.containsKey(studentId)) {
              try {
                debugPrint('Fetching student data for ID: $studentId');
                final studentDoc =
                    await _firestore.collection('users').doc(studentId).get();
                if (studentDoc.exists) {
                  debugPrint('Found student: ${studentDoc['name']}');
                  studentsMap[studentId] = studentDoc;
                } else {
                  debugPrint(
                    'Student document does not exist for ID: $studentId',
                  );
                }
              } catch (e) {
                debugPrint('Error loading student $studentId: $e');
              }
            }
          }
        }

        if (!mounted) return;
        setState(() {
          classes = classesSnapshot.docs;
          students = studentsMap;
          isLoading = false;
          debugPrint('Total students loaded: ${students.length}');
          // Only set selectedClassId if not already set and we have classes
          if (selectedClassId == null && classes.isNotEmpty) {
            selectedClassId = classes.first.id;
          }
        });
      } else {
        debugPrint('No authenticated user found');
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Please sign in to view students';
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Error loading student data';
        });
      }
    }
  }

  Future<void> _viewStudentProfile(
    DocumentSnapshot student,
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    // Get enrolled classes for this student
    final enrolledClasses =
        classes
            .where(
              (c) => (c['students'] as List?)?.contains(student.id) ?? false,
            )
            .toList();

    await showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(
                          (student['name'] as String?)?.isNotEmpty == true
                              ? (student['name'] as String)
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'] ?? 'Unnamed Student',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              student['email'] ?? 'No email',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Student Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            icon: Icons.badge,
                            label: 'Student ID',
                            value: student['studentId'] ?? 'Not set',
                          ),
                          const Divider(),
                          _buildInfoRow(
                            icon: Icons.phone,
                            label: 'Contact',
                            value: student['contact'] ?? 'Not provided',
                          ),
                          const Divider(),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            label: 'Joined',
                            value:
                                student['createdAt'] != null
                                    ? _formatDate(student['createdAt'])
                                    : 'Unknown',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enrolled Classes (${enrolledClasses.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (enrolledClasses.isEmpty)
                    const Text('Not enrolled in any classes')
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: enrolledClasses.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final classData = enrolledClasses[index];
                          return ListTile(
                            title: Text(classData['name'] ?? 'Unnamed Class'),
                            subtitle: Text(
                              classData['description'] ?? 'No description',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: const Icon(Icons.class_),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
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
        title: Text(widget.className ?? 'Student List'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading students...'),
                  ],
                ),
              )
              : hasError
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage ?? 'An error occurred',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : students.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      widget.classId != null
                          ? 'No students in this class yet'
                          : 'No students yet',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.classId != null
                          ? 'Students will appear here when they join this class'
                          : 'Students will appear here when they join your classes',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  if (widget.classId ==
                      null) // Only show dropdown if not class-specific
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
                      padding: const EdgeInsets.all(16),
                      itemCount: _getFilteredStudents().length,
                      itemBuilder: (context, index) {
                        final student = _getFilteredStudents()[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade100,
                              child: Text(
                                (student['name'] as String?)?.isNotEmpty == true
                                    ? (student['name'] as String)
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(student['name'] ?? 'Unnamed Student'),
                            subtitle: Text(student['email'] ?? 'No email'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _viewStudentProfile(student, context),
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
