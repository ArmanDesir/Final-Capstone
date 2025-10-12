import 'package:flutter/material.dart';
import 'package:offline_first_app/models/activity_progress.dart';
import 'package:offline_first_app/models/classroom.dart';
import 'package:offline_first_app/models/user.dart' as local;
import 'package:offline_first_app/providers/auth_provider.dart';
import 'package:offline_first_app/providers/classroom_provider.dart';
import 'package:offline_first_app/screens/join_classroom_screen.dart';
import 'package:offline_first_app/screens/student_classroom_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _completedLessons = 0;
  List<ActivityProgress> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    final classroomProvider =
    Provider.of<ClassroomProvider>(context, listen: false);

    await classroomProvider.loadStudentClassrooms(user.id);
    await _loadRecentActivity(user.id);

    final currentClassroom = classroomProvider.studentClassrooms.isNotEmpty
        ? classroomProvider.studentClassrooms.first
        : null;

    if (currentClassroom != null) {
      final completed = await classroomProvider.getCompletedLessonsCount(
        studentId: user.id,
        classroomId: currentClassroom.id,
      );

      if (mounted) {
        setState(() {
          _completedLessons = completed;
        });
      }
    }
  }

  Future<void> _loadRecentActivity(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('activity_progress_by_classroom')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      final data = response as List;
      setState(() {
        _recentActivities =
            data.map((json) => ActivityProgress.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint('❌ Failed to load recent activity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classroomProvider = Provider.of<ClassroomProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.blue,
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
              Provider.of<AuthProvider>(context, listen: false)
                  .signOutAndRedirect(context);
            },
          ),
        ],
      ),
      body: classroomProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(user?.name ?? 'Student'),
            const SizedBox(height: 24),
            _buildQuickStats(classroomProvider, user),
            const SizedBox(height: 24),
            _buildClassroomStatus(classroomProvider, user),
            const SizedBox(height: 24),
            _buildQuickActions(classroomProvider, user),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $name!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to learn and grow?',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
      ClassroomProvider classroomProvider, local.User? user) {
    final joinedClassrooms = classroomProvider.studentClassrooms.length;
    final contentCount = 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(joinedClassrooms.toString(), 'Classrooms', Colors.blue),
        _buildStatCard(contentCount.toString(), 'Content', Colors.green),
        _buildStatCard(_completedLessons.toString(), 'Completed', Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      width: 100,
      height: 80,
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomStatus(
      ClassroomProvider classroomProvider, local.User? user) {
    final classroom = classroomProvider.currentClassroom;

    if (user?.classroomId == null) {
      return _buildNoClassroomCard(classroomProvider);
    }

    if (classroom == null) {
      return _buildLoadingClassroomCard();
    }

    if (classroom.pendingStudentIds.contains(user!.id)) {
      return _buildPendingStatusCard(classroom);
    }

    if (classroom.studentIds.contains(user.id)) {
      return _buildActiveClassroomCard(classroom);
    }

    return _buildNoClassroomCard(classroomProvider);
  }

  Widget _buildNoClassroomCard(ClassroomProvider classroomProvider) {
    final joinedClassrooms = classroomProvider.studentClassrooms.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '$joinedClassrooms Classroom${joinedClassrooms == 1 ? '' : 's'} Joined',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join another classroom to start learning',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JoinClassroomScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Join Classroom'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingClassroomCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildPendingStatusCard(Classroom classroom) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.pending, size: 48, color: Colors.orange[600]),
            const SizedBox(height: 16),
            Text(
              'Pending Approval',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for teacher to accept your request to join "${classroom.name}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange[600]),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              backgroundColor: Colors.orange[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveClassroomCard(Classroom classroom) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.green[600]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Classroom Code: ${classroom.code ?? ''}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentClassroomScreen(classroom: classroom),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Enter Classroom'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
      ClassroomProvider classroomProvider, local.User? user) {
    final classrooms = classroomProvider.studentClassrooms;
    final hasActiveClassrooms =
        user != null && classrooms.any((c) => c.studentIds.contains(user.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (!hasActiveClassrooms)
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.blue),
              title: const Text('Join Classroom'),
              subtitle: const Text('Enter a classroom code to join'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JoinClassroomScreen(),
                  ),
                );
              },
            ),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.book, color: Colors.blue),
              title: const Text('View Classrooms'),
              subtitle: const Text('Choose a classroom to enter'),
              onTap: () {
                _showClassroomPicker(context, classrooms, user!);
              },
            ),
          ),
      ],
    );
  }

  void _showClassroomPicker(
      BuildContext context, List<Classroom> classrooms, local.User user) {
    final joined =
    classrooms.where((c) => c.studentIds.contains(user.id)).toList();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (joined.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No classrooms joined yet'),
          );
        }

        return ListView.builder(
          itemCount: joined.length,
          itemBuilder: (context, index) {
            final classroom = joined[index];
            return ListTile(
              leading: const Icon(Icons.class_),
              title: Text(classroom.name),
              subtitle: Text('Code: ${classroom.code ?? ''}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentClassroomScreen(classroom: classroom),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_recentActivities.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your learning progress will appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _recentActivities.map((activity) {
              return Card(
                child: ListTile(
                  leading: Icon(
                    _iconForEntityType(activity.entityType),
                    color: Colors.blueAccent,
                  ),
                  title: Text(activity.entityTitle ?? 'Unknown'),
                  subtitle: Text(
                      '${activity.entityType.toUpperCase()} · ${_formatTimeAgo(activity.createdAt)}'),
                  trailing: activity.score != null
                      ? Text('Score: ${activity.score}')
                      : null,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  IconData _iconForEntityType(String type) {
    switch (type.toLowerCase()) {
      case 'lesson':
        return Icons.menu_book;
      case 'quiz':
        return Icons.quiz;
      case 'exercise':
        return Icons.description;
      default:
        return Icons.history;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }
}
