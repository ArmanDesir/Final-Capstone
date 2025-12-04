import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pracpro/services/user_service.dart';
import 'package:pracpro/services/student_quiz_progress_service.dart';
import 'package:pracpro/widgets/quiz_progress_table.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_model;

class EditStudentScreen extends StatefulWidget {
  final app_model.User student;
  const EditStudentScreen({super.key, required this.student});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  late TextEditingController guardianNameController;
  late TextEditingController guardianEmailController;
  late TextEditingController guardianContactController;
  late TextEditingController studentInfoController;

  @override
  void initState() {
    super.initState();
    guardianNameController =
        TextEditingController(text: widget.student.guardianName);
    guardianEmailController =
        TextEditingController(text: widget.student.guardianEmail);
    guardianContactController =
        TextEditingController(text: widget.student.guardianContactNumber);
    studentInfoController =
        TextEditingController(text: widget.student.studentInfo);
  }

  @override
  void dispose() {
    guardianNameController.dispose();
    guardianEmailController.dispose();
    guardianContactController.dispose();
    studentInfoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.student.copyWith(
      guardianName: guardianNameController.text,
      guardianEmail: guardianEmailController.text,
      guardianContactNumber: guardianContactController.text,
      studentInfo: studentInfoController.text,
    );

    await UserService().updateUser(updated);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Student')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: guardianNameController,
              decoration: const InputDecoration(labelText: 'Guardian Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: guardianEmailController,
              decoration: const InputDecoration(labelText: 'Guardian Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: guardianContactController,
              decoration: const InputDecoration(labelText: 'Guardian Contact'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: studentInfoController,
              decoration: const InputDecoration(labelText: 'Student Info'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentId = ModalRoute.of(context)?.settings.arguments as String?;
    final authProvider = Provider.of<AuthProvider>(context);

    if (studentId == null) {
      final user = authProvider.currentUser;
      if (user == null) {
        return const Scaffold(
          body: Center(child: Text('No user data available.')),
        );
      }
      return _ProfileScaffold(
        user: user,
        isTeacher: user.userType == app_model.UserType.teacher,
        loggedInUser: user,
      );
    }

    return FutureBuilder<app_model.User?>(
      future: UserService().getUser(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('No user data available.')),
          );
        }

        final loggedInUser = authProvider.currentUser;
        final isTeacher = loggedInUser?.userType == app_model.UserType.teacher;

        return _ProfileScaffold(
          user: user,
          isTeacher: isTeacher,
          loggedInUser: loggedInUser,
        );
      },
    );
  }
}

class _ProfileScaffold extends StatefulWidget {
  final app_model.User user;
  final bool isTeacher;
  final app_model.User? loggedInUser;

  const _ProfileScaffold({
    required this.user,
    required this.isTeacher,
    required this.loggedInUser,
  });

  @override
  State<_ProfileScaffold> createState() => _ProfileScaffoldState();
}

class _ProfileScaffoldState extends State<_ProfileScaffold> {
  bool _loadingProgress = false;
  List<QuizProgressData> _quizProgress = [];
  List<QuizProgressData> _gameProgress = [];
  String? _classroomId;

  @override
  void initState() {
    super.initState();
    if (widget.user.userType == app_model.UserType.student) {
      _loadStudentProgress();
    }
  }

  Future<void> _loadStudentProgress() async {
    setState(() => _loadingProgress = true);
    try {
      final supabase = Supabase.instance.client;
      
      final classroomsResponse = await supabase
          .from('student_classroom')
          .select('classroom_id')
          .eq('user_id', widget.user.id)
          .eq('status', 'accepted')
          .limit(1);
      
      if (classroomsResponse.isNotEmpty) {
        _classroomId = classroomsResponse.first['classroom_id'];
        
        final service = StudentQuizProgressService();
        final allProgress = await service.getStudentQuizProgress(
          studentId: widget.user.id,
          operator: 'addition',
          classroomId: _classroomId!,
        );
        
        setState(() {
          _quizProgress = allProgress.where((p) => !p.isGame).toList();
          _gameProgress = allProgress.where((p) => p.isGame).toList();
        });
      }
    } catch (e) {
      print('Error loading student progress: $e');
    } finally {
      setState(() => _loadingProgress = false);
    }
  }

  void _editStudent(BuildContext context) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditStudentScreen(student: widget.user),
      ),
    );

    if (updated == true) {
      final refreshed = await UserService().getUser(widget.user.id);
      if (refreshed != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _ProfileScaffold(
              user: refreshed,
              isTeacher: widget.isTeacher,
              loggedInUser: widget.loggedInUser,
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    if (widget.loggedInUser == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    final path = 'avatars/${widget.loggedInUser!.id}_${DateTime.now().millisecondsSinceEpoch}.png';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client.storage
          .from('pictures')
          .upload(
        path,
        File(image.path),
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/png',
        ),
      );

      final publicUrl = Supabase.instance.client.storage
          .from('pictures')
          .getPublicUrl(path);

      final updatedUser = widget.loggedInUser!.copyWith(photoUrl: publicUrl);
      await UserService().updateUser(updatedUser);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUserProfile();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture uploaded successfully!')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.loggedInUser?.id == widget.user.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isTeacher &&
              widget.user.userType == app_model.UserType.student &&
              !isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editStudent(context),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            Center(
              child: GestureDetector(
                onTap: isOwnProfile ? () => _pickAndUploadImage(context) : null,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: widget.user.photoUrl != null
                      ? NetworkImage(widget.user.photoUrl!)
                      : null,
                  child: widget.user.photoUrl == null
                      ? Icon(
                    widget.user.userType == app_model.UserType.teacher
                        ? Icons.person
                        : Icons.school,
                    size: 48,
                    color: Colors.blue,
                  )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileField(label: 'Full Name', value: widget.user.name),
            const SizedBox(height: 16),
            _ProfileField(label: 'Email', value: widget.user.email ?? 'N/A'),
            const SizedBox(height: 16),
            _ProfileField(label: 'Guardian Name', value: widget.user.guardianName ?? 'N/A'),
            const SizedBox(height: 16),
            _ProfileField(label: 'Guardian Email', value: widget.user.guardianEmail ?? 'N/A'),
            const SizedBox(height: 16),
            _ProfileField(
                label: 'Guardian Contact', value: widget.user.guardianContactNumber ?? 'N/A'),
            const SizedBox(height: 16),
            _ProfileField(label: 'Student Info', value: widget.user.studentInfo ?? 'N/A'),
            
            if (widget.user.userType == app_model.UserType.student) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.assessment, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'My Progress',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_loadingProgress)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_classroomId == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Not enrolled in any classroom yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else ...[
                if (_quizProgress.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.quiz, color: Colors.deepPurple, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Quizzes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  QuizProgressTable(quizData: _quizProgress),
                  const SizedBox(height: 24),
                ],
                
                if (_gameProgress.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.sports_esports, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Games',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  QuizProgressTable(quizData: _gameProgress),
                ],
                
                if (_quizProgress.isEmpty && _gameProgress.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No progress yet. Start learning!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
