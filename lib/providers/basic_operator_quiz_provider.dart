import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BasicOperatorQuizProvider with ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> get quizzes => _quizzes;

  Future<void> loadQuizzes(String operator) async {
    try {
      final data = await supabase
          .from('basic_operator_quizzes')
          .select('id, operator, title, basic_operator_quiz_questions (id)')           .eq('operator', operator);

      _quizzes = (data as List).map((q) {
        return {
          'id': q['id'],
          'operator': q['operator'],
          'title': q['title'] ?? 'Untitled Quiz',
          'questions': q['basic_operator_quiz_questions'] ?? [],
        };
      }).toList();

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createQuiz({
    required String operator,
    required String title,
    required List<Map<String, dynamic>> questions,
    required String teacherId,
  }) async {
    try {
      final quiz = await supabase.from('basic_operator_quizzes').insert({
        'operator': operator,
        'title': title,
        'created_by': teacherId,
      }).select().single();

      final quizId = quiz['id'];
      for (final q in questions) {
        await supabase.from('basic_operator_quiz_questions').insert({
          'quiz_id': quizId,
          'question_text': q['q'],
          'choice_a': q['options'][0],
          'choice_b': q['options'][1],
          'choice_c': q['options'][2],
          'correct_choice': q['a'],
        });
      }

      await loadQuizzes(operator);
    } catch (e) {
      rethrow;
    }
  }
}

