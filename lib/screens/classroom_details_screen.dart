import 'package:flutter/material.dart';
import 'package:pracpro/models/classroom.dart';
import 'package:pracpro/models/content.dart';
import 'package:pracpro/models/user.dart' as app_model;
import 'package:pracpro/providers/classroom_provider.dart';
import 'package:pracpro/screens/create_lesson_screen.dart';
import 'package:pracpro/screens/create_quiz_screen.dart';
import 'package:pracpro/screens/lesson_detail_screen.dart';
import 'package:pracpro/services/content_service.dart';
import 'package:pracpro/services/exercise_service.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassroomDetailsScreen extends StatefulWidget {
  final Classroom classroom;
  const ClassroomDetailsScreen({super.key, required this.classroom});

  @override
  State<ClassroomDetailsScreen> createState() => _ClassroomDetailsScreenState();
}

class _ClassroomDetailsScreenState extends State<ClassroomDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContentService _contentService = ContentService();
  List<Content> _contentList = [];
  bool _isLoadingContent = false;
  final ExerciseService _exerciseService = ExerciseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClassroomProvider>(
        context,
        listen: false,
      ).loadClassroomDetails(widget.classroom.id);

      _loadContent();
    });
  }


  Future<void> _loadContent() async {
    setState(() => _isLoadingContent = true);
    try {
      _contentList = await _contentService.getContentByClassroom(
        widget.classroom.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load content: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final classroom = provider.currentClassroom ?? widget.classroom;
        return Scaffold(
          appBar: AppBar(
            title: Text('Classroom: ${classroom.name}'),
            backgroundColor: Colors.green,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Students'),
                Tab(icon: Icon(Icons.book), text: 'Content'),
              ],
            ),
          ),
          body:
              provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStudentsTab(classroom, provider),
                      _buildContentTab(classroom),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildStudentsTab(Classroom classroom, ClassroomProvider provider) {
    final acceptedStudents = provider.acceptedStudents
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final pendingStudents = provider.pendingStudents
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

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
                    classroom.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Code: ${classroom.code ?? ''}'),
                  if ((classroom.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(classroom.description!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Accepted Students (${acceptedStudents.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          acceptedStudents.isEmpty
              ? const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No students have joined yet.'),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: acceptedStudents.length,
            itemBuilder: (context, idx) {
              final student = acceptedStudents[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color.alphaBlend(
                      Colors.green.withAlpha((0.1 * 255).toInt()),
                      Colors.white,
                    ),
                    child: Text(
                      student.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ),
                  title: Text(student.name),
                  subtitle: Text(student.email ?? 'No email'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _showRemoveStudentDialog(classroom.id, student),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.pending, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Pending Requests (${pendingStudents.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          pendingStudents.isEmpty
              ? const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No pending requests.'),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingStudents.length,
            itemBuilder: (context, idx) {
              final student = pendingStudents[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color.alphaBlend(
                      Colors.orange.withAlpha((0.1 * 255).toInt()),
                      Colors.white,
                    ),
                    child: Text(
                      student.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                  title: Text(student.name),
                  subtitle: Text(student.email ?? 'No email'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () async {
                          await provider.acceptStudent(
                            classroomId: classroom.id,
                            studentId: student.id,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${student.name} accepted!')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () async {
                          await provider.rejectStudent(classroom.id, student.id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${student.name} rejected.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab(Classroom classroom) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classroom Content',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _buildContentCard(
            'Lessons',
            'Create and manage lessons',
            Icons.book,
            Colors.blue,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateLessonScreen(
                    classroomId: classroom.id,
                  ),
                ),
              ).then((created) {
                if (created == true) {
                  _loadContent();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          _buildContentCard(
            'Quizzes',
            'Create and manage quizzes',
            Icons.quiz,
            Colors.purple,
                () async {
              final allContents = await _contentService.getContentByClassroom(classroom.id);
              if (!mounted) return;
              final classroomLessons = allContents.where((c) => c.type == ContentType.lesson).toList();
              if (classroomLessons.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No lessons available in this classroom.')),
                );
                return;
              }

              final selectedLesson = await showDialog<Content>(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: const Text("Choose Lesson"),
                    children: classroomLessons.map((lesson) {
                      return SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, lesson),
                        child: Text(lesson.title),
                      );
                    }).toList(),
                  );
                },
              );

              if (selectedLesson != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateQuizScreen(
                      classroomId: classroom.id,
                      lessonId: selectedLesson.id,
                    ),
                  ),
                ).then((created) {
                  if (created == true) {
                    _loadContent();
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _buildContentCard(
            'Exercises',
            'Upload practice exercises and worksheets',
            Icons.fitness_center,
            Colors.orange,
            () => _showUploadDialog('exercise', ContentType.exercise),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Recent Content',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (_isLoadingContent)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingContent
              ? const Center(child: CircularProgressIndicator())
              : _contentList.isEmpty
              ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No content uploaded yet.'),
                ),
              )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _contentList.length,
            itemBuilder: (context, index) {
              final content = _contentList[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color.alphaBlend(
                      _getContentColor(content.type).withAlpha((0.1 * 255).toInt()),
                      Colors.white,
                    ),
                    child: Icon(
                      _getContentIcon(content.type),
                      color: _getContentColor(content.type),
                    ),
                  ),
                  title: Text(content.title),
                  subtitle: Text(
                    '${content.description ?? ''}\n'
                        '${_formatFileSize(content.fileSize ?? 0)} • ${_formatDate(content.createdAt)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteContentDialog(content),
                  ),
                  onTap: () {
                    if (content.type == ContentType.lesson) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonDetailScreen(content: content),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Opening for ${content.type} not yet implemented")),
                      );
                    }
                  },
                ),
              );
            },
          )
          ,
        ],
      ),
    );
  }

  Widget _buildContentCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color.alphaBlend(
            color.withAlpha((0.1 * 255).toInt()),
            Colors.white,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.add),
        onTap: onTap,
      ),
    );
  }

  void _showRemoveStudentDialog(String classroomId, app_model.User student) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Student'),
            content: Text(
              'Are you sure you want to remove ${student.name} from this classroom?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final provider = Provider.of<ClassroomProvider>(
                    context,
                    listen: false,
                  );
                  await provider.removeStudent(classroomId, student.id);
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${student.name} removed from classroom.')),
                      );
                    }
                  });
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showUploadDialog(String contentType, ContentType type) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add ${contentType[0].toUpperCase() + contentType.substring(1)}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload New File"),
              onPressed: () {
                Navigator.pop(context);
                _showUploadForm(type, contentType, titleController, descController);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.content_copy),
              label: const Text("Use Existing Content"),
              onPressed: () {
                Navigator.pop(context);
                _showSelectExistingContent(type);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(ContentType type, String title, String description, File file,) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Upload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: $title'),
            const SizedBox(height: 8),
            Text('Description: $description'),
            const SizedBox(height: 8),
            Text('File: ${file.path.split('/').last}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _uploadPDFFile(type, title, description, file);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPDFFile(ContentType type, String title, String description, File file,) async {
    try {
      if (type == ContentType.exercise) {
        await _exerciseService.createExercise(
          classroomId: widget.classroom.id,
          userId: Supabase.instance.client.auth.currentUser!.id,
          title: title,
          description: description,
          pdfFile: file,
        );
      } else {
        await _contentService.createContent(
          classroomId: widget.classroom.id,
          title: title,
          description: description,
          type: type,
          pdfFile: file,
        );
      }

      await _loadContent();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSelectExistingContent(ContentType type) async {
    try {
      final allContents = await _contentService.getAllContents(type: type);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Select Existing Content"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allContents.length,
              itemBuilder: (context, index) {
                final content = allContents[index];
                return ListTile(
                  leading: Icon(_getContentIcon(content.type)),
                  title: Text(content.title),
                  subtitle: Text(content.description ?? ''),
                  onTap: () async {
                    Navigator.pop(context);
                    await _contentService.attachExistingContent(
                      classroomId: widget.classroom.id,
                      contentId: content.id,
                    );
                    await _loadContent();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${content.title} added to this classroom!')),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch existing content: $e')),
      );
    }
  }

  void _showUploadForm(ContentType type, String contentType, TextEditingController titleController, TextEditingController descController,) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload ${contentType[0].toUpperCase() + contentType.substring(1)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter content title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Enter content description',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    descController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title and description are required.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final result = await _contentService.pickPDFFile();
                if (result != null && result.files.isNotEmpty) {
                  final file = File(result.files.first.path!);
                  Navigator.pop(context);
                  _showConfirmDialog(
                    type,
                    titleController.text.trim(),
                    descController.text.trim(),
                    file,
                  );
                }
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose PDF File'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteContentDialog(Content content) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final messenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Delete Content'),
          content: Text('Are you sure you want to delete "${content.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _contentService.deleteContent(
                    contentId: content.id,
                    type: content.type,
                  );
                  await _loadContent();
                  Navigator.pop(dialogContext);

                  messenger.showSnackBar(
                    SnackBar(content: Text('${content.title} deleted.')),
                  );
                } catch (e) {
                  Navigator.pop(dialogContext);

                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getContentColor(ContentType type) {
    switch (type) {
      case ContentType.lesson:
        return Colors.blue;
      case ContentType.quiz:
        return Colors.purple;
      case ContentType.exercise:
        return Colors.orange;
    }
  }

  IconData _getContentIcon(ContentType type) {
    switch (type) {
      case ContentType.lesson:
        return Icons.book;
      case ContentType.quiz:
        return Icons.quiz;
      case ContentType.exercise:
        return Icons.fitness_center;
    }
  }

  String _formatFileSize(int size) {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
