import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student_pages/student_dashboard.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  StudentRegisterPageState createState() => StudentRegisterPageState();
}

class StudentRegisterPageState extends State<StudentRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String name = '';
  String email = '';
  String studentId = '';
  String contactNumber = '';
  String password = '';
  bool _isLoading = false;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Validate student ID format
        if (!RegExp(r'^\d{7}$').hasMatch(studentId)) {
          throw 'Student ID must be 7 digits';
        }

        // Validate contact number format
        if (!RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(contactNumber)) {
          throw 'Invalid contact number format';
        }

        // Check if student ID already exists
        final existingStudent =
            await _firestore
                .collection('users')
                .where('studentId', isEqualTo: studentId)
                .get();

        if (existingStudent.docs.isNotEmpty) {
          throw 'Student ID already registered';
        }

        // Create user account
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        // Add user details to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'studentId': studentId.trim(),
          'contactNumber': contactNumber.trim(),
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentDashboard()),
        );
      } catch (e) {
        if (!mounted) return;
        final message = e is String ? e : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  hintText: 'Enter your 7-digit student ID',
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => studentId = val,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter your Student ID';
                  }
                  if (!RegExp(r'^\d{7}$').hasMatch(val)) {
                    return 'Student ID must be 7 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  hintText: 'Enter your contact number',
                ),
                keyboardType: TextInputType.phone,
                onChanged: (val) => contactNumber = val,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter your contact number';
                  }
                  if (!RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(val)) {
                    return 'Enter a valid contact number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (val) => name = val,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter your name';
                  }
                  if (val.trim().split(' ').length < 2) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email address',
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (val) => email = val,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter an email';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(val)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
