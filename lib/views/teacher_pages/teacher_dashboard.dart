import 'package:flutter/material.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Teacher Dashboard')),
      body: Center(
        child: Text(
          'Welcome to the Teacher Dashboard',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
