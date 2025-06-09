import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student_pages/exercise_details.dart';

class StudentExercisesPage extends StatefulWidget {
  final String classId;

  const StudentExercisesPage({super.key, required this.classId});

  @override
  State<StudentExercisesPage> createState() => _StudentExercisesPageState();
}

class _StudentExercisesPageState extends State<StudentExercisesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      debugPrint('Loading exercises for class: ${widget.classId}');
      final exercisesQuery =
          await _firestore
              .collection('exercises')
              .where('classId', isEqualTo: widget.classId)
              .orderBy('createdAt', descending: true)
              .get();

      debugPrint('Exercises loaded: ${exercisesQuery.docs.length}');

      if (!mounted) return;
      setState(() {
        exercises = exercisesQuery.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading exercises: $e')));
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('StudentExercisesPage: classId = ${widget.classId}');
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : exercises.isEmpty
              ? const Center(child: Text('No exercises found'))
              : ListView.builder(
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return ListTile(
                    title: Text(exercise['title'] ?? 'Unknown'),
                    subtitle: Text(exercise['description'] ?? 'No description'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ExerciseDetails(
                                exercise:
                                    exercise.data() as Map<String, dynamic>,
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
