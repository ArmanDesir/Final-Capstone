import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherProfile extends StatefulWidget {
  const TeacherProfile({super.key});

  @override
  State<TeacherProfile> createState() => _TeacherProfileState();
}

class _TeacherProfileState extends State<TeacherProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> teacherData = {
    'name': '',
    'email': '',
    'teacher_id': '',
    'cont_number': '',
  };

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    if (!mounted) return;
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      if (snapshot.exists) {
        setState(() {
          teacherData = {
            'name': snapshot['name'] ?? '',
            'email': snapshot['email'] ?? '',
            'teacher_id': snapshot['teacher_id'] ?? '',
            'cont_number': snapshot['cont_number'] ?? '',
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          ProfileInfoCard(
            title: 'Teacher Information',
            items: [
              ProfileItem(label: 'Name', value: teacherData['name']),
              ProfileItem(label: 'Email', value: teacherData['email']),
              ProfileItem(
                label: 'Teacher ID',
                value: teacherData['teacher_id'],
              ),
              ProfileItem(
                label: 'Contact Number',
                value: teacherData['cont_number'],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<ProfileItem> items;

  const ProfileInfoCard({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }
}

class ProfileItem extends StatelessWidget {
  final String label;
  final String value;

  const ProfileItem({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
          const Divider(),
        ],
      ),
    );
  }
}
