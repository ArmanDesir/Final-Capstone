import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/basic_operator_quiz.dart';

class BasicOperatorQuizViewScreen extends StatefulWidget {
  final BasicOperatorQuiz quiz;
  const BasicOperatorQuizViewScreen({super.key, required this.quiz});

  @override
  State<BasicOperatorQuizViewScreen> createState() =>
      _BasicOperatorQuizViewScreenState();
}

class _BasicOperatorQuizViewScreenState
    extends State<BasicOperatorQuizViewScreen> {
  final supabase = Supabase.instance.client;

  final Map<String, String> _selectedAnswers = {};
  bool _submitted = false;
  bool _isTeacher = false;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  /// ✅ Detect if current user is teacher
  Future<void> _checkUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('users')
        .select('user_type')
        .eq('id', user.id)
        .maybeSingle();

    setState(() {
      _isTeacher = res?['user_type'] == 'teacher';
      _loadingUser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz.questions;

    if (_loadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        backgroundColor: Colors.lightBlue,
      ),
      body: questions.isEmpty
          ? const Center(child: Text('No questions found for this quiz.'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ...questions.map((q) => _buildQuestionCard(q)),
            const SizedBox(height: 24),
            if (!_isTeacher)
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text(_submitted ? 'Retake Quiz' : 'Submit Answers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _submitted ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  setState(() {
                    if (_submitted) {
                      _submitted = false;
                      _selectedAnswers.clear();
                    } else {
                      _submitted = true;
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BasicOperatorQuizQuestion q) {
    final choices = {
      'A': q.choiceA,
      'B': q.choiceB,
      'C': q.choiceC,
    };

    final selected = _selectedAnswers[q.id] ?? '';
    final correct = q.correctChoice;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${widget.quiz.questions.indexOf(q) + 1}. ${q.questionText}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...choices.entries.map((entry) {
              final letter = entry.key;
              final text = entry.value;
              Color? color;
              if (_submitted && !_isTeacher) {
                if (letter == correct) {
                  color = Colors.green[100];
                } else if (letter == selected && selected != correct) {
                  color = Colors.red[100];
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == letter
                        ? Colors.blue
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: RadioListTile<String>(
                  value: letter,
                  groupValue: selected,
                  title: Text('$letter. $text'),
                  activeColor: Colors.blue,
                  onChanged: _submitted || _isTeacher
                      ? null
                      : (value) {
                    setState(() {
                      _selectedAnswers[q.id ?? ''] = value!;
                    });
                  },
                ),
              );
            }),

            if (_isTeacher || _submitted)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_box, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Correct Answer: $correct',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
