import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/views/teacher_pages/teacher_lessons.dart';
import 'package:capstone_project/views/teacher_pages/teacher_exercises.dart';
import 'package:capstone_project/views/teacher_pages/teacher_quizzes.dart';
import 'package:capstone_project/views/teacher_pages/teacher_class_list.dart';
import 'package:capstone_project/views/teacher_pages/teacher_student_list.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String teacherName = "Teacher";
  String? teacherPhotoUrl;
  String? teacherId;
  String? teacherContact;
  bool isLoading = true;
  int _selectedIndex = 0;
  Map<String, dynamic> dashboardStats = {'totalClasses': 0, 'totalStudents': 0};

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
    _loadDashboardStats();
  }

  Future<void> _loadTeacherData() async {
    if (!mounted) return;
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!mounted) return;
        if (doc.exists) {
          setState(() {
            teacherName = doc['name'] ?? 'Teacher';
            teacherPhotoUrl = doc['photoUrl'];
            teacherId = doc['teacherId'];
            teacherContact = doc['contact'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading teacher data: $e');
    }
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get total classes
        final classesQuery =
            await _firestore
                .collection('classes')
                .where('teacherId', isEqualTo: user.uid)
                .get();

        int totalStudents = 0;
        for (var doc in classesQuery.docs) {
          List students = doc['students'] ?? [];
          totalStudents += students.length;
        }

        if (!mounted) return;
        setState(() {
          dashboardStats = {
            'totalClasses': classesQuery.docs.length,
            'totalStudents': totalStudents,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final navigationContext = context;
    if (!navigationContext.mounted) return;

    final shouldLogout = await showDialog<bool>(
      context: navigationContext,
      builder:
          (dialogContext) => AlertDialog(
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

    if (!navigationContext.mounted) return;
    if (shouldLogout == true) {
      await _auth.signOut();
      if (!navigationContext.mounted) return;
      Navigator.pushReplacementNamed(navigationContext, '/teacher_login');
    }
  }

  Future<void> _updateTeacherProfile() async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    final nameController = TextEditingController(text: teacherName);
    final idController = TextEditingController(text: teacherId);
    final contactController = TextEditingController(text: teacherContact);

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final currentContext = context;
                      if (!currentContext.mounted) return;

                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );

                      if (image != null) {
                        final user = _auth.currentUser;
                        if (user != null) {
                          try {
                            final File imageFile = File(image.path);
                            final ref = FirebaseStorage.instance
                                .ref()
                                .child('profile_photos')
                                .child('${user.uid}.jpg');

                            await ref.putFile(imageFile);
                            final url = await ref.getDownloadURL();

                            await _firestore
                                .collection('users')
                                .doc(user.uid)
                                .update({'photoUrl': url});

                            if (!mounted) return;
                            setState(() {
                              teacherPhotoUrl = url;
                            });

                            if (!currentContext.mounted) return;
                            Navigator.pop(currentContext);
                            _loadTeacherData();
                          } catch (e) {
                            if (!currentContext.mounted) return;
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Error uploading image'),
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              teacherPhotoUrl != null
                                  ? NetworkImage(teacherPhotoUrl!)
                                  : null,
                          child:
                              teacherPhotoUrl == null
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher ID',
                      hintText: 'Enter your teacher ID',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      hintText: 'Enter your contact number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _auth.currentUser?.email ?? 'No email',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final user = _auth.currentUser;
                  if (user != null) {
                    try {
                      await _firestore
                          .collection('users')
                          .doc(user.uid)
                          .update({
                            'name': nameController.text.trim(),
                            'teacherId': idController.text.trim(),
                            'contact': contactController.text.trim(),
                          });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _loadTeacherData();
                    } catch (e) {
                      debugPrint('Error updating profile: $e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error updating profile')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _showProfileDialog() async {
    final dialogContext = context;
    if (!dialogContext.mounted) return;

    await showDialog(
      context: dialogContext,
      builder:
          (context) => AlertDialog(
            title: const Text('Teacher Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      teacherPhotoUrl != null
                          ? NetworkImage(teacherPhotoUrl!)
                          : null,
                  child:
                      teacherPhotoUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                ),
                const SizedBox(height: 16),
                Text(
                  teacherName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Teacher ID: ${teacherId ?? 'Not set'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _auth.currentUser?.email ?? 'No email',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact: ${teacherContact ?? 'Not set'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateTeacherProfile();
                },
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: _confirmLogout,
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
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
                    'Quick Stats',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Classes',
                          value: dashboardStats['totalClasses'].toString(),
                          icon: Icons.class_,
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TeacherClassList(),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Students',
                          value: dashboardStats['totalStudents'].toString(),
                          icon: Icons.people,
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TeacherStudentList(),
                                ),
                              ),
                        ),
                      ),
                    ],
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
                    'Management',
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
                        title: 'Manage Classes',
                        subtitle: 'Create and manage class codes',
                        icon: Icons.class_,
                        color: Colors.blue,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeacherClassList(),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Manage Lessons',
                        subtitle: 'Create and edit lessons',
                        icon: Icons.book,
                        color: Colors.green,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeacherLessons(),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Manage Exercises',
                        subtitle: 'Create and edit exercises',
                        icon: Icons.edit_document,
                        color: Colors.orange,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeacherExercises(),
                              ),
                            ),
                      ),
                      _MenuCard(
                        title: 'Manage Quizzes',
                        subtitle: 'Create and edit quizzes',
                        icon: Icons.quiz,
                        color: Colors.purple,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeacherQuizzes(),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $teacherName'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: _buildDashboardContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1) {
            _showProfileDialog();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
