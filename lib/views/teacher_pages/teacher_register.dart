import 'package:capstone_project/views/teacher_pages/teacher_login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  TeacherRegisterPageState createState() => TeacherRegisterPageState();
}

class TeacherRegisterPageState extends State<TeacherRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String name = '';
  String email = '';
  String password = '';
  Future<void> registerTeacher() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(email: email, password: password);

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'password': password,
          'teacher_id': 'teacher_id',
          'cont_number': 'cont_number',
          'role': 'teacher',
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher Registered Successfully')),
        );

        // Navigate to the teacher login page after registration
        Navigator.of(context).pushReplacementNamed('/teacher_login');
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        String message = 'Registration Error';
        if (e.code == 'email-already-in-use') {
          message = 'The email address is already in use.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is invalid.';
        } else if (e.code == 'weak-password') {
          message = 'The password is too weak.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registered Succesfuly')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Teacher Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Teacher ID'),
                onChanged: (val) => name = val,
                validator:
                    (val) => val!.isEmpty ? 'Enter You Teacher ID' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'First Name'),
                onChanged: (val) => name = val,
                validator: (val) => val!.isEmpty ? 'Enter your name' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Contact Number'),
                onChanged: (val) => name = val,
                validator: (val) => val!.isEmpty ? 'Enter your name' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                onChanged: (val) => email = val,
                validator: (val) => val!.isEmpty ? 'Enter an email' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                onChanged: (val) => password = val,
                validator:
                    (val) =>
                        val!.length < 6
                            ? 'Password must be 6+ characters'
                            : null,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: registerTeacher,
                    child: Text('Register'),
                  ),
                  SizedBox(width: 20, height: 100), // Space between the buttons
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherLoginPage(),
                        ),
                      );
                    },
                    child: Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
