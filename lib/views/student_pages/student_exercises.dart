import 'package:flutter/material.dart';

class StudentExercisesPage extends StatelessWidget {
  const StudentExercisesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Exercises')),
      body: Center(
        child: Text(
          'Student Exercises Form Goes Here',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
