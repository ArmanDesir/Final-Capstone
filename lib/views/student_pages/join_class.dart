import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinClass extends StatefulWidget {
  const JoinClass({super.key});

  @override
  State<JoinClass> createState() => _JoinClassState();
}

class _JoinClassState extends State<JoinClass> {
  final _formKey = GlobalKey<FormState>();
  final _classCodeController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _joinClass() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final classCode = _classCodeController.text.trim().toUpperCase();

        // Find the class with this code
        final classQuery =
            await _firestore
                .collection('classes')
                .where('classCode', isEqualTo: classCode)
                .limit(1)
                .get();

        if (classQuery.docs.isEmpty) {
          throw 'Invalid class code. Please check and try again.';
        }

        final classDoc = classQuery.docs.first;
        final currentUser = _auth.currentUser;

        if (currentUser == null) {
          throw 'You must be logged in to join a class';
        }

        // Check if student is already in the class
        final classData = classDoc.data();
        final students = List<String>.from(classData['students'] ?? []);

        if (students.contains(currentUser.uid)) {
          throw 'You are already enrolled in this class';
        }

        // Add student to the class
        students.add(currentUser.uid);
        await classDoc.reference.update({'students': students});

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the class!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _classCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Class')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the class code provided by your teacher',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _classCodeController,
                decoration: const InputDecoration(
                  labelText: 'Class Code',
                  hintText: 'Enter 6-digit class code',
                  prefixIcon: Icon(Icons.class_),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the class code';
                  }
                  if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(value.toUpperCase())) {
                    return 'Invalid class code format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinClass,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Join Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
