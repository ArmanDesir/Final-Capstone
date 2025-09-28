import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizProvider with ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> lessonQuizzes = [];
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> get quizzes => _quizzes;

  Future<void> loadQuizzesForLesson(String lessonId) async {
    try {
      final data = await supabase
          .from('quizzes')
          .select(
          'id, title, classroom_id, quiz_questions(id, question_text, choice_a, choice_b, choice_c, correct_choice)')
          .eq('lesson_id', lessonId);

      lessonQuizzes = (data as List<dynamic>).map((q) {
        return {
          'id': q['id'],
          'title': q['title'],
          'classroom_id': q['classroom_id'],
          'questions': (q['quiz_questions'] as List<dynamic>).map((qq) {
            return {
              'q': qq['question_text'],
              'options': [qq['choice_a'], qq['choice_b'], qq['choice_c']],
              'a': qq['correct_choice'],
            };
          }).toList(),
        };
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading lesson quizzes: $e");
      rethrow;
    }
  }

  Future<void> loadQuizzes(String teacherId) async {
    try {
      final data = await supabase
          .from('quizzes')
          .select('id, title, classroom_id, quiz_questions (id)')
          .eq('created_by', teacherId);

      _quizzes = (data as List<dynamic>).map((q) {
        return {
          'id': q['id'],
          'title': q['title'],
          'classroom_id': q['classroom_id'],
          'questions': q['quiz_questions'] ?? [],
        };
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading quizzes: $e");
    }
  }

  Future<void> createQuiz({
    required String classroomId,
    required String lessonId,
    required String title,
    required List<Map<String, dynamic>> questions,
    required String teacherId,
  }) async {
    try {
      final quiz = await supabase.from('quizzes').insert({
        'classroom_id': classroomId,
        'lesson_id': lessonId,
        'title': title,
        'created_by': teacherId,
      }).select().single();

      final quizId = quiz['id'];

      for (final q in questions) {
        await supabase.from('quiz_questions').insert({
          'quiz_id': quizId,
          'question_text': q['q'],
          'choice_a': q['options'][0],
          'choice_b': q['options'][1],
          'choice_c': q['options'][2],
          'correct_choice': q['a'],
        });
      }

      await loadQuizzes(teacherId);
    } catch (e) {
      debugPrint("Error creating quiz: $e");
      rethrow;
    }
  }
}
