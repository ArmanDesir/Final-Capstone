import 'package:flutter/material.dart';
import 'package:pracpro/models/basic_operator_lesson.dart';
import 'package:pracpro/models/basic_operator_quiz.dart';
import 'package:pracpro/models/basic_operator_exercise.dart';
import 'package:pracpro/modules/basic_operators/addition/game_screen.dart';
import 'package:pracpro/screens/basic_operator_lesson_view_screen.dart';
import 'package:pracpro/screens/basic_operator_quiz_screen.dart';
import 'package:pracpro/screens/create_content_screen.dart';
import 'package:pracpro/services/basic_operator_lesson_service.dart';
import 'package:pracpro/services/basic_operator_quiz_service.dart';
import 'package:pracpro/services/basic_operator_exercise_service.dart';
import 'package:pracpro/services/unlock_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BasicOperatorModulePage extends StatefulWidget {
  final String operatorName;
  final String? classroomId;

  const BasicOperatorModulePage({
    super.key,
    required this.operatorName,
    this.classroomId,
  });

  @override
  State<BasicOperatorModulePage> createState() =>
      _BasicOperatorModulePageState();
}

class _BasicOperatorModulePageState extends State<BasicOperatorModulePage>
    with SingleTickerProviderStateMixin {
  final _lessonService = BasicOperatorLessonService();
  final _quizService = BasicOperatorQuizService();
  final _exerciseService = BasicOperatorExerciseService();
  final _unlockService = UnlockService();
  late TabController _tabController;

  bool _isLoadingLessons = true;
  bool _isLoadingQuizzes = true;
  bool _isLoadingExercises = true;
  String? _lessonError;
  String? _quizError;
  String? _exerciseError;
  List<BasicOperatorLesson> _lessons = [];
  List<BasicOperatorQuiz> _quizzes = [];
  List<BasicOperatorExercise> _exercises = [];
  Set<String> _unlockedLessons = {};
  Set<String> _unlockedQuizzes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllContent();
  }

  Future<void> _loadAllContent() async {
    // Load content first, then unlocks (so we can initialize first unlocks if needed)
    await Future.wait([
      _loadLessons(),
      _loadQuizzes(),
      _loadExercises(),
    ]);
    // Load unlocks after content is loaded
    await _loadUnlockedItems();
  }

  Future<void> _loadUnlockedItems() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final unlocked = await _unlockService.getUnlockedItems(
        userId: user.id,
        operator: widget.operatorName,
        classroomId: widget.classroomId,
      );

      setState(() {
        _unlockedLessons = unlocked['lessons'] ?? {};
      });

      // Initialize first unlocks if nothing is unlocked yet
      if (_unlockedLessons.isEmpty && _lessons.isNotEmpty) {
        await _unlockService.initializeFirstUnlocks(
          userId: user.id,
          operator: widget.operatorName,
          classroomId: widget.classroomId,
        );
        // Reload unlocks
        final refreshed = await _unlockService.getUnlockedItems(
          userId: user.id,
          operator: widget.operatorName,
          classroomId: widget.classroomId,
        );
        setState(() {
          _unlockedLessons = refreshed['lessons'] ?? {};
        });
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  Future<void> _loadLessons() async {
    try {
      setState(() {
        _isLoadingLessons = true;
        _lessonError = null;
      });
      final lessons = await _lessonService.getLessons(
        widget.operatorName,
        classroomId: widget.classroomId,
      );
      // Sort lessons by creation date (oldest first) for proper unlock sequence
      lessons.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });
      setState(() => _lessons = lessons);
    } catch (e) {
      setState(() => _lessonError = e.toString());
    } finally {
      setState(() => _isLoadingLessons = false);
    }
  }

  Future<void> _loadQuizzes() async {
    try {
      setState(() {
        _isLoadingQuizzes = true;
        _quizError = null;
      });
      final quizzes = await _quizService.getQuizzes(
        widget.operatorName,
        classroomId: widget.classroomId,
      );
      // Sort quizzes by creation date (oldest first) for proper unlock sequence
      quizzes.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });
      setState(() => _quizzes = quizzes);
    } catch (e) {
      setState(() => _quizError = e.toString());
    } finally {
      setState(() => _isLoadingQuizzes = false);
    }
  }

  Future<void> _loadExercises() async {
    try {
      setState(() {
        _isLoadingExercises = true;
        _exerciseError = null;
      });
      final exercises = await _exerciseService.getExercises(
        widget.operatorName,
        classroomId: widget.classroomId,
      );

      setState(() => _exercises = exercises);
    } catch (e) {
      setState(() => _exerciseError = e.toString());
    } finally {
      setState(() => _isLoadingExercises = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${widget.operatorName[0].toUpperCase()}${widget.operatorName.substring(1)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('$title Module'),
        backgroundColor: Colors.lightBlue,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Lessons'),
            Tab(icon: Icon(Icons.quiz), text: 'Quizzes'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
            Tab(icon: Icon(Icons.videogame_asset), text: 'Games'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLessonsTab(),
          _buildQuizzesTab(),
          _buildExercisesTab(),
          GameScreen(operatorKey: widget.operatorName),
        ],
      ),
    );
  }

  Widget _buildLessonsTab() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    Future<bool> _isTeacher() async {
      if (user == null) return false;
      try {
        final res = await supabase
            .from('users')
            .select('user_type')
            .eq('id', user.id)
            .maybeSingle();
        return res?['user_type'] == 'teacher';
      } catch (e) {
        return false;
      }
    }

    return FutureBuilder<bool>(
      future: _isTeacher(),
      builder: (context, teacherSnapshot) {
        final isTeacher = teacherSnapshot.data ?? false;
        final showCreateButtons = isTeacher && widget.classroomId != null;

    if (_isLoadingLessons) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lessonError != null) {
      return Center(child: Text('Error: $_lessonError'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLessons();
        await _loadUnlockedItems();
      },
          child: Column(
            children: [
              if (showCreateButtons) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create Lesson'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateContentScreen(
                                  operator: widget.operatorName,
                                  contentType: 'lesson',
                                  classroomId: widget.classroomId,
                                ),
                              ),
                            ).then((_) => _loadLessons());
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.quiz),
                          label: const Text('Create Quiz'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateContentScreen(
                                  operator: widget.operatorName,
                                  contentType: 'quiz',
                                  classroomId: widget.classroomId,
                                ),
                              ),
                            ).then((_) => _loadLessons());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
              ],
              Expanded(
                child: _lessons.isEmpty
                    ? const Center(child: Text('No lessons available yet.'))
                    : ListView.builder(
        itemCount: _lessons.length,
        itemBuilder: (context, index) {
          final lesson = _lessons[index];
          // First lesson (oldest by creation date) should be unlocked by default
          // Lessons are sorted oldest first, so index 0 is the oldest
          final isOldestLesson = index == 0;
          final isUnlocked = lesson.id == null || 
              isOldestLesson || 
              _unlockedLessons.contains(lesson.id);
          final isFirstLesson = isOldestLesson;
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isUnlocked ? Colors.orange[50] : Colors.grey[200],
            child: ListTile(
              leading: Icon(
                isUnlocked ? Icons.book : Icons.lock,
                color: isUnlocked ? Colors.blueAccent : Colors.grey,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      lesson.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🔒 Locked',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                isUnlocked 
                    ? (lesson.description ?? 'No description provided')
                    : 'Complete previous lessons to unlock',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked ? null : Colors.grey[500],
                ),
              ),
              trailing: Icon(
                isUnlocked ? Icons.arrow_forward_ios_rounded : Icons.lock_outline,
                color: isUnlocked ? null : Colors.grey,
              ),
              onTap: isUnlocked ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BasicOperatorLessonViewScreen(
                      lesson: lesson,
                    ),
                  ),
                ).then((_) => _loadUnlockedItems());
              } : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('🔒 This lesson is locked. Complete previous content to unlock it.'),
                    backgroundColor: Colors.orange,
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ),
                );
              },
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
  }

  Widget _buildQuizzesTab() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (_isLoadingQuizzes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quizError != null) {
      return Center(child: Text('Error: $_quizError'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadQuizzes();
        await _loadUnlockedItems();
      },
      child: _quizzes.isEmpty
          ? const Center(child: Text('No quizzes available yet.'))
          : ListView.builder(
              itemCount: _quizzes.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final quiz = _quizzes[index];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.purple[50],
                  child: ListTile(
                    leading: const Icon(
                      Icons.quiz,
                      color: Colors.purpleAccent,
                    ),
                    title: Text(
                      quiz.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('${quiz.questions.length} questions'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded),
                    onTap: user != null ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BasicOperatorQuizScreen(
                            quiz: quiz,
                            userId: user.id,
                          ),
                        ),
                      ).then((_) async {
                        await Future.wait([
                          _loadQuizzes(),
                          _loadUnlockedItems(),
                          _loadLessons(), // Reload lessons to reflect unlock status
                        ]);
                      });
                    } : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildExercisesTab() {
    if (_isLoadingExercises) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exerciseError != null) {
      return Center(child: Text('Error: $_exerciseError'));
    }

    return RefreshIndicator(
      onRefresh: _loadExercises,
      child: _exercises.isEmpty
          ? const Center(child: Text('No exercises available yet.'))
          : ListView.builder(
              itemCount: _exercises.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.green[50],
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center, color: Colors.greenAccent),
                    title: Text(
                      exercise.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      exercise.description ?? 'No description provided',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: exercise.fileUrl != null
                        ? const Icon(Icons.attachment, color: Colors.green)
                        : const Icon(Icons.arrow_forward_ios_rounded),
                    onTap: () {
                      if (exercise.fileUrl != null) {

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening: ${exercise.fileName ?? exercise.title}'),
                            action: SnackBarAction(
                              label: 'Open',
                              onPressed: () {

                              },
                            ),
                          ),
                        );
                      }
              },
            ),
          );
        },
      ),
    );
  }
}
