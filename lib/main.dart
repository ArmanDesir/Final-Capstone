import 'package:capstone_project/views/get_started_page.dart';
import 'package:capstone_project/views/teacher_pages/teacher_login.dart';
import 'package:capstone_project/views/student_pages/student_login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyBDmsi8yrGsckcNeyqAqwdPseJ7nqAXPoc',
      appId: '1:300783079351:android:57c08858b143542901e232',
      messagingSenderId: '300783079351',
      projectId: 'capstone-proj-final',
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PracProMath',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const GetStartedPage(), // initial screen
      routes: {
        '/teacher_login':
            (context) => const TeacherLoginPage(), // <-- route definition
        '/student_login': (context) => const StudentLoginPage(),
      },
    );
  }
}
