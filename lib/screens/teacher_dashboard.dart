import 'package:flutter/material.dart';
import 'package:offline_first_app/models/user.dart' as app_model;
import 'package:offline_first_app/providers/auth_provider.dart';
import 'package:offline_first_app/providers/classroom_provider.dart';
import 'package:offline_first_app/providers/quiz_provider.dart';
import 'package:offline_first_app/screens/QuizDetailsScreen.dart';
import 'package:offline_first_app/screens/classroom_details_screen.dart';
import 'package:offline_first_app/screens/manage_classrooms_screen.dart';
import 'package:provider/provider.dart';

class CreateClassroomScreen extends StatelessWidget {
  final String teacherId;
  const CreateClassroomScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final classroomProvider = Provider.of<ClassroomProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Classroom')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Classroom Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await classroomProvider.createClassroom(
                    name: nameController.text,
                    description: descController.text,
                  );
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
            if (classroomProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  classroomProvider.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final GlobalKey _classroomListKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  int _lessonsCount = 0;
  int _quizzesCount = 0;
  List<app_model.User> _acceptedStudents = [];
  Map<String, List<app_model.User>> _studentsByClassroom = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final classroomProvider = Provider.of<ClassroomProvider>(context, listen: false);

      final teacherId = authProvider.currentUser?.id ?? '';

      try {
        await classroomProvider.loadTeacherClassrooms();

        final counts = await classroomProvider.getContentCountsForTeacher(teacherId);
        final acceptedStudents = await classroomProvider.getAcceptedStudentsForAllClassrooms();
        final groupedStudents = await classroomProvider.getStudentsGroupedByClassroom();

        if (mounted) {
          setState(() {
            _lessonsCount = counts['lessons'] ?? 0;
            _quizzesCount = counts['quizzes'] ?? 0;
            _acceptedStudents = acceptedStudents;
            _studentsByClassroom = groupedStudents;
          });
        }

      } catch (e, stack) {
        print(stack);
      }
    });
  }

  void _scrollToClassrooms() {
    if (_classroomListKey.currentContext != null) {
      Scrollable.ensureVisible(
        _classroomListKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final classroomProvider = Provider.of<ClassroomProvider>(context);
    final quizProvider = Provider.of<QuizProvider>(context);

    final acceptedStudentsCount = classroomProvider.teacherClassrooms
        .fold<int>(0, (sum, c) => sum + c.studentIds.length);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Teacher Dashboard'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: classroomProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: _scrollToClassrooms,
                child: _buildStatCard(
                  '${classroomProvider.teacherClassrooms.length}',
                  'Classrooms',
                  Colors.blue,
                ),
              ),
              _buildStatCard(
                '$acceptedStudentsCount',
                'Students',
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('$_lessonsCount', 'Lessons', Colors.orange),
              _buildStatCard('$_quizzesCount', 'Quizzes', Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text(
                'Manage Classroom',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Create, update, or delete your classrooms',
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageClassroomsScreen(),
                  ),
                );
                Provider.of<ClassroomProvider>(
                  context,
                  listen: false,
                ).loadTeacherClassrooms();
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Classrooms',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (classroomProvider.teacherClassrooms.isEmpty)
            Center(
              child: Text(
                'No classrooms yet. Tap "Create Classroom" to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          else ...[
            ...classroomProvider.teacherClassrooms.take(3).map(
                  (classroom) => Container(
                key: classroom == classroomProvider.teacherClassrooms.first
                    ? _classroomListKey
                    : null,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(
                        Icons.class_,
                        color: Colors.green,
                      ),
                    ),
                    title: Text(
                      classroom.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Code: ${classroom.code ?? ''}\nStudents: ${classroom.studentIds.length}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassroomDetailsScreen(
                            classroom: classroom,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (classroomProvider.teacherClassrooms.length > 3)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageClassroomsScreen(),
                    ),
                  );
                },
                child: const Text('See All Classrooms'),
              ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Accepted Students',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (acceptedStudentsCount == 0)
            Center(
              child: Text(
                'No accepted students yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          else
            Column(
              children: _acceptedStudents.map((student) {
                return Card(
                  child: ListTile(
                    leading:
                    const Icon(Icons.person, color: Colors.green),
                    title: Text(student.name ?? 'Unknown'),
                    subtitle: Text(student.email ?? 'No email'),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        if (student.id != null) {
                          Navigator.pushNamed(
                            context,
                            '/profile',
                            arguments: student.id,
                          );
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          const Text(
            'Quizzes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (quizProvider.quizzes.isEmpty)
            Center(
              child: Text(
                'No quizzes yet. Tap "Create Quiz" to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          else
            ...quizProvider.quizzes.map(
                  (quiz) => Card(
                child: ListTile(
                  leading: const Icon(Icons.quiz, color: Colors.purple),
                  title: Text(quiz['title'] ?? 'Untitled Quiz'),
                  subtitle:
                  Text('${quiz['questions']?.length ?? 0} Questions'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizDetailsScreen(quiz: quiz),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      width: 140,
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withAlpha((0.08 * 255).toInt()),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.alphaBlend(
            color.withAlpha((0.2 * 255).toInt()),
            Colors.white,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 16, color: color)),
        ],
      ),
    );
  }
}
