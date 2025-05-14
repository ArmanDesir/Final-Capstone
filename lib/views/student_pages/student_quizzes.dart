import 'package:flutter/material.dart';

class StudentQuizzessPage extends StatelessWidget {
  const StudentQuizzessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Quizzess')),
      body: Center(
        child: Text(
          'Student Quizzess Form Goes Here',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
