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

    final classroomProvider = Provider.of<ClassroomProvider>(context, listen: false);

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
      if (mounted) setState(() => _completedLessons = completed);
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

      final data = (response as List).cast<Map<String, dynamic>>();
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
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOutAndRedirect(context),
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
            _buildQuickStats(classroomProvider),
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
            color: Colors.black.withOpacity(0.08),
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
            'Keep up the great work and continue learning!',
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ClassroomProvider classroomProvider) {
    final joinedClassrooms = classroomProvider.studentClassrooms.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(joinedClassrooms.toString(), 'Classrooms', Colors.blue),
        _buildStatCard(_completedLessons.toString(), 'Completed', Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomStatus(
      ClassroomProvider classroomProvider, local.User? user) {
    final classroom = classroomProvider.currentClassroom;

    if (user?.classroomId == null) {
      return _buildNoClassroomCard();
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

    return _buildNoClassroomCard();
  }

  Widget _buildNoClassroomCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No classrooms joined yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join a classroom to begin your learning journey.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinClassroomScreen()),
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

  Widget _buildLoadingClassroomCard() => const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ));

  Widget _buildPendingStatusCard(Classroom classroom) {
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, size: 46, color: Colors.orange[600]),
            const SizedBox(height: 12),
            Text(
              'Pending Approval for "${classroom.name}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              backgroundColor: Colors.orange[200],
              valueColor:
              AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveClassroomCard(Classroom classroom) {
    return Card(
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded, color: Colors.green[700], size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('Code: ${classroom.code ?? ''}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
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
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(
              hasActiveClassrooms ? Icons.book_rounded : Icons.add_circle_rounded,
              color: Colors.blue,
            ),
            title: Text(
                hasActiveClassrooms ? 'View Classrooms' : 'Join Classroom'),
            subtitle: Text(hasActiveClassrooms
                ? 'Choose a classroom to enter'
                : 'Enter a classroom code to join'),
            onTap: () {
              if (hasActiveClassrooms) {
                _showClassroomPicker(context, classrooms, user!);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinClassroomScreen()),
                );
              }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
    final filtered = _recentActivities
        .where((a) =>
    a.entityTitle != null &&
        !a.entityTitle!.toLowerCase().contains('addition_cross') &&
        !a.entityTitle!.toLowerCase().contains('subtraction_cross') &&
        !a.entityTitle!.toLowerCase().contains('multiplication_cross') &&
        !a.entityTitle!.toLowerCase().contains('division_cross'))
        .toList();

    final recent = filtered.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (filtered.length > 3)
              TextButton(
                onPressed: () => _showAllActivities(filtered),
                child: const Text(
                  'See More',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (recent.isEmpty)
          Card(
            color: Colors.grey[50],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your progress will appear here once you start learning.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: recent.map((activity) {
              final scoreText =
              activity.score != null ? 'Score: ${activity.score}' : '';
              final timeAgo = _formatTimeAgo(activity.createdAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Icon(
                      _iconForEntityType(activity.entityType),
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    activity.entityTitle ?? 'Untitled Activity',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${activity.stage} • $timeAgo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  trailing: scoreText.isNotEmpty
                      ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      scoreText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  )
                      : null,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showAllActivities(List<ActivityProgress> activities) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Recent Activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final a = activities[index];
                        final scoreText =
                        a.score != null ? 'Score: ${a.score}' : '';
                        final timeAgo = _formatTimeAgo(a.createdAt);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              child: Icon(
                                _iconForEntityType(a.entityType),
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              a.entityTitle ?? 'Untitled Activity',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              '${a.stage} • $timeAgo',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            trailing: scoreText.isNotEmpty
                                ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                scoreText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForEntityType(String type) {
    switch (type.toLowerCase()) {
      case 'lesson':
        return Icons.menu_book_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'exercise':
        return Icons.fitness_center_rounded;
      case 'game':
        return Icons.videogame_asset_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }
}
