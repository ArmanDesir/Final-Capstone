import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'join_class.dart';
import 'student_class_details.dart';

class StudentClasses extends StatefulWidget {
  const StudentClasses({super.key});

  @override
  State<StudentClasses> createState() => _StudentClassesState();
}

class _StudentClassesState extends State<StudentClasses> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<DocumentSnapshot> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get all classes where the student is enrolled
        final querySnapshot =
            await _firestore
                .collection('classes')
                .where('students', arrayContains: user.uid)
                .orderBy('createdAt', descending: true)
                .get();

        if (!mounted) return;
        setState(() {
          _classes = querySnapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading classes: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinNewClass() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const JoinClass()),
    );

    if (result == true) {
      _loadClasses(); // Refresh the class list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadClasses),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _joinNewClass,
        child: const Icon(Icons.add),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _classes.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'You haven\'t joined any classes yet',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _joinNewClass,
                      icon: const Icon(Icons.add),
                      label: const Text('Join a Class'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final classData =
                      _classes[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(classData['name'] ?? 'Unnamed Class'),
                      subtitle: Text(
                        classData['description'] ?? 'No description',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => StudentClassDetails(
                                  classDoc: _classes[index],
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}
