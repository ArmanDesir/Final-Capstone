import 'package:flutter/material.dart';
import 'package:offline_first_app/models/basic_operator_lesson.dart';
import 'package:offline_first_app/models/basic_operator_quiz.dart';
import 'package:offline_first_app/screens/basic_operator_lesson_view_screen.dart';
import 'package:offline_first_app/screens/basic_operator_quiz_view_screen.dart';
import 'package:offline_first_app/services/basic_operator_lesson_service.dart';
import 'package:offline_first_app/services/basic_operator_quiz_service.dart';

/// Displays all lessons and quizzes for a selected operator (e.g. Addition, Subtraction)
class BasicOperatorLessonAndQuizPage extends StatefulWidget {
  final String operatorName;

  const BasicOperatorLessonAndQuizPage({
    super.key,
    required this.operatorName,
  });

  @override
  State<BasicOperatorLessonAndQuizPage> createState() =>
      _BasicOperatorLessonAndQuizPageState();
}

class _BasicOperatorLessonAndQuizPageState
    extends State<BasicOperatorLessonAndQuizPage>
    with SingleTickerProviderStateMixin {
  final _lessonService = BasicOperatorLessonService();
  final _quizService = BasicOperatorQuizService();

  late TabController _tabController;

  bool _isLoadingLessons = true;
  bool _isLoadingQuizzes = true;
  String? _lessonError;
  String? _quizError;

  List<BasicOperatorLesson> _lessons = [];
  List<BasicOperatorQuiz> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLessons();
    _loadQuizzes();
  }

  Future<void> _loadLessons() async {
    try {
      setState(() {
        _isLoadingLessons = true;
        _lessonError = null;
      });

      final lessons = await _lessonService.getLessons(widget.operatorName);
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

      final quizzes = await _quizService.getQuizzes(widget.operatorName);
      setState(() => _quizzes = quizzes);
    } catch (e) {
      setState(() => _quizError = e.toString());
    } finally {
      setState(() => _isLoadingQuizzes = false);
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
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Lessons'),
            Tab(icon: Icon(Icons.quiz), text: 'Quizzes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLessonsTab(),
          _buildQuizzesTab(),
        ],
      ),
    );
  }

  Widget _buildLessonsTab() {
    if (_isLoadingLessons) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lessonError != null) {
      return Center(child: Text('Error: $_lessonError'));
    }
    if (_lessons.isEmpty) {
      return const Center(child: Text('No lessons available yet.'));
    }

    return RefreshIndicator(
      onRefresh: _loadLessons,
      child: ListView.builder(
        itemCount: _lessons.length,
        itemBuilder: (context, index) {
          final lesson = _lessons[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.orange[50],
            child: ListTile(
              leading: const Icon(Icons.book, color: Colors.blueAccent),
              title: Text(
                lesson.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                lesson.description ?? 'No description provided',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BasicOperatorLessonViewScreen(lesson: lesson),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizzesTab() {
    if (_isLoadingQuizzes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quizError != null) {
      return Center(child: Text('Error: $_quizError'));
    }
    if (_quizzes.isEmpty) {
      return const Center(child: Text('No quizzes available yet.'));
    }

    return RefreshIndicator(
      onRefresh: _loadQuizzes,
      child: ListView.builder(
        itemCount: _quizzes.length,
        itemBuilder: (context, index) {
          final quiz = _quizzes[index];
          final questionCount = quiz.questions.length;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.blue[50],
            child: ListTile(
              leading: const Icon(Icons.quiz, color: Colors.deepPurple),
              title: Text(
                quiz.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '$questionCount question${questionCount == 1 ? '' : 's'}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BasicOperatorQuizViewScreen(quiz: quiz),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
