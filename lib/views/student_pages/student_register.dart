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
        debugPrint('Before createUserWithEmailAndPassword');
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        debugPrint('After createUserWithEmailAndPassword');

        final user = userCredential.user;
        if (user == null) {
          debugPrint('Firebase User object is NULL after creation.');
          throw 'Firebase User object is null after creation.';
        }
        debugPrint('User created with UID: ${user.uid}');

        // Add user details to Firestore
        debugPrint(
          'Attempting to write user details to Firestore for UID: ${user.uid}',
        );
        await _firestore.collection('users').doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'studentId': studentId.trim(),
          'contactNumber': contactNumber.trim(),
          'role': 'student',
          'classId':
              'roRBWR2aj3lc1CvwcgZN', // Automatically assign to the default class
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('User data successfully written to Firestore.');

        if (!mounted) return;

        // Fetch the updated user document to get the classId
        debugPrint('Fetching updated user document for classId.');
        final updatedDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final String userClassId =
            updatedDoc.data() != null &&
                    updatedDoc.data()!.containsKey('classId')
                ? updatedDoc['classId']
                : '';
        debugPrint('Fetched userClassId: $userClassId');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDashboard(classId: userClassId),
          ),
        );
      } catch (e) {
        debugPrint('Caught error during registration: ${e.toString()}');
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
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                ),
                obscureText: true, // Hides the input characters
                onChanged: (val) => password = val,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (val.length < 6) {
                    return 'Password must be at least 6 characters';
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
