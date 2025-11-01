import 'package:flutter/material.dart';
import 'package:pracpro/models/basic_operator_lesson.dart';
import 'package:pracpro/modules/basic_operators/addition/game_screen.dart';
import 'package:pracpro/screens/basic_operator_lesson_view_screen.dart';
import 'package:pracpro/services/basic_operator_lesson_service.dart';

class BasicOperatorModulePage extends StatefulWidget {
  final String operatorName;

  const BasicOperatorModulePage({super.key, required this.operatorName});

  @override
  State<BasicOperatorModulePage> createState() =>
      _BasicOperatorModulePageState();
}

class _BasicOperatorModulePageState extends State<BasicOperatorModulePage>
    with SingleTickerProviderStateMixin {
  final _lessonService = BasicOperatorLessonService();
  late TabController _tabController;

  bool _isLoadingLessons = true;
  String? _lessonError;
  List<BasicOperatorLesson> _lessons = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLessons();
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
            Tab(icon: Icon(Icons.videogame_asset), text: 'Games'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLessonsTab(),
          GameScreen(operatorKey: widget.operatorName),
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
                    builder: (_) => BasicOperatorLessonViewScreen(
                      lesson: lesson,
                    ),
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
