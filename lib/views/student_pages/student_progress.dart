import 'package:flutter/material.dart';

class StudentProgressPage extends StatelessWidget {
  const StudentProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Progress')),
      body: Center(
        child: Text(
          'Student Progress Form Goes Here',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
