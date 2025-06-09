import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student_pages/student_profile.dart';

class StudentList extends StatelessWidget {
  final String classId;

  const StudentList({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('students')
                .where('classId', isEqualTo: classId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No students found'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final student = snapshot.data!.docs[index];
              return ListTile(
                title: Text(student['name'] ?? 'Unknown'),
                subtitle: Text(student['email'] ?? 'No email'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => StudentProfile(
                            student: student.data() as Map<String, dynamic>,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
