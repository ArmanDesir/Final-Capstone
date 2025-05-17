import 'package:capstone_project/views/student_pages/student_login.dart';
import 'package:capstone_project/views/student_pages/student_profile.dart';
import 'package:capstone_project/views/student_pages/student_settings.dart';
import 'package:capstone_project/views/student_pages/student_exercises.dart';
import 'package:capstone_project/views/student_pages/student_lessons.dart';
import 'package:capstone_project/views/student_pages/student_progress.dart';
import 'package:capstone_project/views/student_pages/student_quizzes.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const StudentDashboard(),
      routes: {'/login': (context) => StudentLoginPage()},
    );
  }
}

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String studentName = "Student";
  int _selectedIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final List<Widget> _pages;
  final List<String> _titles = ['', 'Profile', 'Settings'];

  @override
  void initState() {
    super.initState();
    _fetchStudentName();
    _pages = [
      const StudentHomePage(),
      const StudentProfile(),
      const StudentSettings(),
    ];
  }

  Future<void> _confirmLogout() async {
    if (!mounted) return;
    final navigationContext = context;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (!mounted) return;
    if (shouldLogout == true) {
      await _auth.signOut();
      if (!mounted) return;
      if (navigationContext.mounted) {
        Navigator.pushReplacementNamed(navigationContext, '/student_login');
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _fetchStudentName() async {
    if (!mounted) return;
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      if (snapshot.exists && snapshot['name'] != null) {
        setState(() {
          studentName = snapshot['name'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!mounted) return;
        final navigationContext = context;
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder:
              (BuildContext dialogContext) => AlertDialog(
                title: const Text('Exit App'),
                content: const Text('Do you want to logout and exit?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Logout'),
                  ),
                ],
              ),
        );

        if (!mounted) return;
        if (shouldLogout == true) {
          await _auth.signOut();
          if (!mounted) return;
          if (navigationContext.mounted) {
            Navigator.pushReplacementNamed(navigationContext, '/student_login');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedIndex == 0
                ? 'Hello, $studentName'
                : (_selectedIndex < _titles.length
                    ? _titles[_selectedIndex]
                    : ''),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: Colors.redAccent,
          child: ListView(
            children: [
              DrawerHeader(
                child: Text(
                  'Welcome, $studentName',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Lessons'),
                onTap: () => _navigateTo(const StudentLessonsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Exercises'),
                onTap: () => _navigateTo(const StudentExercisesPage()),
              ),
              ListTile(
                leading: const Icon(Icons.quiz),
                title: const Text('Quizzes'),
                onTap: () => _navigateTo(const StudentQuizzessPage()),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Progress'),
                onTap: () => _navigateTo(const StudentProgressPage()),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Welcome to your Dashboard!', style: TextStyle(fontSize: 22)),
    );
  }
}
