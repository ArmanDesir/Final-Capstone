import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:offline_first_app/screens/lesson_detail_screen.dart';
import '../models/classroom.dart';
import '../models/content.dart';

class StudentClassroomScreen extends StatefulWidget {
  final Classroom classroom;
  const StudentClassroomScreen({super.key, required this.classroom});

  @override
  State<StudentClassroomScreen> createState() => _StudentClassroomScreenState();
}

class _TabInfo {
  final String title;
  final IconData icon;
  final ContentType? contentType;

  _TabInfo({required this.title, required this.icon, this.contentType});
}

class _StudentClassroomScreenState extends State<StudentClassroomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Content> _lessons = [];
  List<Content> _exercises = [];
  bool _isLoadingContent = true;
  String? _errorMessage;

  final _tabs = [
    _TabInfo(title: 'Lessons', icon: Icons.book, contentType: ContentType.lesson),
    _TabInfo(title: 'Exercises', icon: Icons.fitness_center, contentType: ContentType.exercise),
    _TabInfo(title: 'Basic Operators', icon: Icons.calculate),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoadingContent = true;
      _errorMessage = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final data = await Supabase.instance.client
          .rpc('get_lessons_with_access', params: {
        'p_user_id': userId,
        'p_classroom_id': widget.classroom.id,
      }) as List<dynamic>;

      final allContent = data.map((e) {
        return Content(
          id: e['lesson_id'] as String,
          classroomId: e['classroom_id'] as String,
          title: e['title'] as String,
          description: e['description'] as String?,
          type: _mapType(e['type'] as String?),
          fileSize: e['file_size'] as int?,
          fileUrl: e['file_url'] as String?,
          createdAt: DateTime.parse(e['created_at'] as String),
          updatedAt: DateTime.parse(e['updated_at'] as String),
          isUnlocked: e['is_unlocked'] as bool? ?? false,
        );
      }).toList();

      _lessons = allContent.where((c) => c.type == ContentType.lesson).toList();
      _exercises = allContent.where((c) => c.type == ContentType.exercise).toList();

    } catch (e) {
      print('Error loading content: $e');
      if (!mounted) return;

      _errorMessage = 'Failed to load content. Please try again later.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  ContentType _mapType(String? type) {
    switch (type) {
      case 'lesson':
        return ContentType.lesson;
      case 'exercise':
        return ContentType.exercise;
      case 'quiz':
        return ContentType.quiz;
      default:
        return ContentType.lesson;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Classroom: ${widget.classroom.name}'),
        backgroundColor: Colors.blue,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((tab) => Tab(icon: Icon(tab.icon), text: tab.title)).toList(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadContent,
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((tab) {
        if (tab.contentType != null) {
          return _buildContentTab(tab.contentType!, tab.title);
        } else {
          return _buildBasicOperatorsTab();
        }
      }).toList(),
    );
  }

  Widget _buildContentTab(ContentType contentType, String title) {
    final filteredContent = switch (contentType) {
      ContentType.lesson => _lessons,
      ContentType.exercise => _exercises,
      ContentType.quiz => <Content>[],
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.classroom.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${widget.classroom.code ?? ''}'),
                  if (widget.classroom.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.classroom.description),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${filteredContent.length} items',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredContent.isEmpty)
            _buildEmptyState(contentType)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredContent.length,
              itemBuilder: (context, index) {
                final content = filteredContent[index];
                return _buildContentCard(content);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBasicOperatorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.orange[50],
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.calculate, color: Colors.orange),
              title: const Text('Basic Operators'),
              subtitle: const Text('Practice Addition, Subtraction, and more!'),
              onTap: () {
                Navigator.pushNamed(context, '/basic_operations');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ContentType contentType) {
    IconData icon;
    String message;
    Color color;

    switch (contentType) {
      case ContentType.lesson:
        icon = Icons.book_outlined;
        message = 'No lessons uploaded yet';
        color = Colors.blue;
        break;
      case ContentType.quiz:
        icon = Icons.quiz_outlined;
        message = 'No quizzes available yet';
        color = Colors.purple;
        break;
      case ContentType.exercise:
        icon = Icons.fitness_center_outlined;
        message = 'No exercises assigned yet';
        color = Colors.orange;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: color.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teacher will upload content here soon',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(Content content) {
    final isLocked = !content.isUnlocked;

    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isLocked ? Colors.grey[200] : Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: content.type.color.withOpacity(isLocked ? 0.05 : 0.1),
              child: Icon(
                content.type.icon,
                color: isLocked ? Colors.grey : content.type.color,
              ),
            ),
            title: Text(
              content.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.type != ContentType.quiz && content.description != null) ...[
                  Text(
                    content.description!,
                    style: TextStyle(color: isLocked ? Colors.grey : Colors.black),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    if (content.type != ContentType.quiz && content.fileSize != null) ...[
                      Icon(Icons.file_present, size: 16, color: isLocked ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatFileSize(content.fileSize!),
                        style: TextStyle(fontSize: 12, color: isLocked ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Icon(Icons.calendar_today, size: 16, color: isLocked ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(content.createdAt),
                      style: TextStyle(fontSize: 12, color: isLocked ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: Icon(
              Icons.chevron_right,
              color: isLocked ? Colors.grey : Colors.black,
            ),
            onTap: content.isUnlocked
                ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonDetailScreen(content: content),
                ),
              );
            }
                : null,
          ),
        ),
        if (isLocked)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}