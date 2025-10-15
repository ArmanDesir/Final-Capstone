import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/basic_operator_quiz.dart';

class BasicOperatorQuizService {
  final SupabaseClient _sb = Supabase.instance.client;

  /// ✅ Fetch quizzes by operator (final stable version)
  Future<List<BasicOperatorQuiz>> getQuizzes(String operator) async {
    final data = await _sb
        .from('basic_operator_quizzes')
        .select('*, basic_operator_quiz_questions(*)')
        .eq('operator', operator)
        .order('created_at', ascending: false);

    if (data == null) return [];

    return (data as List).map((row) {
      final quizMap = Map<String, dynamic>.from(row);
      quizMap['questions'] = quizMap['basic_operator_quiz_questions'] ?? [];

      return BasicOperatorQuiz.fromJson(quizMap);
    }).toList();
  }

  /// Create quiz and its questions
  Future<void> createQuiz({
    required String operator,
    required String title,
    required List<Map<String, dynamic>> questions,
    required String teacherId,
  }) async {
    final quiz = await _sb.from('basic_operator_quizzes').insert({
      'operator': operator,
      'title': title,
      'created_by': teacherId,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    final quizId = quiz['id'];
    for (final q in questions) {
      await _sb.from('basic_operator_quiz_questions').insert({
        'quiz_id': quizId,
        'question_text': q['q'],
        'choice_a': q['options'][0],
        'choice_b': q['options'][1],
        'choice_c': q['options'][2],
        'correct_choice': q['a'],
      });
    }
  }

  /// Delete quiz and its questions
  Future<void> deleteQuiz(String quizId) async {
    await _sb.from('basic_operator_quiz_questions').delete().eq('quiz_id', quizId);
    await _sb.from('basic_operator_quizzes').delete().eq('id', quizId);
  }
}
