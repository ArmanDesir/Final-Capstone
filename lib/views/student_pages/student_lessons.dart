import 'package:flutter/material.dart';

class StudentLessonsPage extends StatelessWidget {
  const StudentLessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Lessons'), centerTitle: true),
      body: Center(
        child: Text(
          'Student Lessons Form Goes Here',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
