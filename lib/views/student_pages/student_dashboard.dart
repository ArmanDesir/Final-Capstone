import 'package:flutter/material.dart';

class StudentDashboardPage extends StatelessWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Dashboard')),
      body: Center(
        child: Text(
          'Student Dashboard Form Goes Here',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
