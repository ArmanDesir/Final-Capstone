import 'package:capstone_project/views/student_pages/student_login.dart';
import 'package:capstone_project/views/student_pages/student_profile.dart';
import 'package:capstone_project/views/student_pages/student_settings.dart';
import 'package:capstone_project/views/student_pages/student_exercises.dart';
import 'package:capstone_project/views/student_pages/student_lessons.dart';
import 'package:capstone_project/views/student_pages/student_progress.dart';
import 'package:capstone_project/views/student_pages/student_quizzes.dart';
import 'package:capstone_project/views/student_pages/student_classes.dart';

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
      home: const StudentDashboard(classId: ''),
      routes: {'/login': (context) => StudentLoginPage()},
    );
  }
}

class StudentDashboard extends StatefulWidget {
  final String classId;

  const StudentDashboard({super.key, required this.classId});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String studentName = "Student";
  int _selectedIndex = 0;
  bool _isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _titles = ['', 'Profile', 'Settings'];

  @override
  void initState() {
    super.initState();
    _fetchStudentName();
  }

  Future<void> _fetchStudentName() async {
    if (!mounted) return;
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        debugPrint('Fetching user data for: ${user.uid}');
        DocumentSnapshot snapshot =
            await _firestore.collection('users').doc(user.uid).get();
        debugPrint('User data fetched: ${snapshot.exists}');
        if (!mounted) return;
        if (snapshot.exists && snapshot['name'] != null) {
          setState(() {
            studentName = snapshot['name'];
            _isLoading = false;
          });
          debugPrint('Student name set to: $studentName');
        } else {
          debugPrint(
            'User data exists but name is null or document does not exist',
          );
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      debugPrint('No user is currently logged in');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _getCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return StudentDashboardHomePage(
          classId: widget.classId,
          studentName: studentName,
        );
      case 1:
        return StudentProfile(student: {});
      case 2:
        return const StudentSettings();
      default:
        return const Center(child: Text('Page not found'));
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
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getCurrentPage(),
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

class StudentDashboardHomePage extends StatelessWidget {
  final String classId;
  final String studentName;

  const StudentDashboardHomePage({
    super.key,
    required this.classId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // You might want to refresh student specific data here
        // As this is a StatelessWidget, you'd trigger a refresh from a parent StatefulWidget if needed
        // For now, _fetchStudentName() is still in _StudentDashboardState
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Class Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Class ID: $classId',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Learning Journey',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _MenuCard(
                        title: 'Lessons',
                        subtitle: 'View your lessons',
                        icon: Icons.book,
                        color: Colors.green,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => StudentLessonsPage(classId: classId),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Exercises',
                        subtitle: 'Practice with exercises',
                        icon: Icons.edit_document,
                        color: Colors.orange,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        StudentExercisesPage(classId: classId),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Quizzes',
                        subtitle: 'Test your knowledge',
                        icon: Icons.quiz,
                        color: Colors.purple,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => StudentQuizzes(classId: classId),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Progress',
                        subtitle: 'Track your progress',
                        icon: Icons.bar_chart,
                        color: Colors.blue,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentProgressPage(),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Classes',
                        subtitle: 'Manage your classes',
                        icon: Icons.class_,
                        color: Colors.teal,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentClasses(),
                              ),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withAlpha((0.8 * 255).round()), color],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
