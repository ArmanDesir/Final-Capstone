import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/basic_operator_quiz.dart';
import 'student_dashboard.dart';

class BasicOperatorQuizScreen extends StatefulWidget {
  final BasicOperatorQuiz quiz;
  final String userId;

  const BasicOperatorQuizScreen({
    super.key,
    required this.quiz,
    required this.userId,
  });

  @override
  State<BasicOperatorQuizScreen> createState() =>
      _BasicOperatorQuizScreenState();
}

class _BasicOperatorQuizScreenState extends State<BasicOperatorQuizScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selected = -1;
  int _score = 0;
  int _current = 0;
  bool _quizFinished = false;
  bool _locked = false;
  bool _answered = false;
  late Timer _timer;
  int _remainingSeconds = 300;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAttempts();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _checkAttempts() async {
    try {
      final res = await supabase
          .from('basic_operator_quiz_progress')
          .select()
          .eq('user_id', widget.userId)
          .eq('quiz_id', widget.quiz.id!)
          .maybeSingle();

      if (res != null && (res['attempts_count'] ?? 0) >= 3) {
        setState(() => _locked = true);
        return;
      }

      _startTimer();
    } catch (e) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _finishQuiz();
      }
    });
  }

  Future<void> _saveProgress() async {
    try {
      final total = widget.quiz.questions.length;
      final percent = (_score / total * 100).round();

      final existing = await supabase
          .from('basic_operator_quiz_progress')
          .select()
          .eq('user_id', widget.userId)
          .eq('quiz_id', widget.quiz.id!)
          .maybeSingle();

      if (existing == null || existing.isEmpty) {
        await supabase.from('basic_operator_quiz_progress').insert({
          'user_id': widget.userId,
          'quiz_id': widget.quiz.id,
          'try1_score': percent,
          'highest_score': percent,
          'attempts_count': 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        int attempts = (existing['attempts_count'] ?? 0) + 1;
        if (attempts > 3) attempts = 3;

        int try1 = existing['try1_score'] ?? 0;
        int try2 = existing['try2_score'] ?? 0;
        int try3 = existing['try3_score'] ?? 0;

        if (attempts == 2 && try2 == 0) try2 = percent;
        if (attempts == 3 && try3 == 0) try3 = percent;

        final highest =
        [try1, try2, try3, percent].reduce((a, b) => a > b ? a : b);

        await supabase.from('basic_operator_quiz_progress').update({
          'try1_score': try1,
          'try2_score': try2,
          'try3_score': try3,
          'highest_score': highest,
          'attempts_count': attempts,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', widget.userId).eq('quiz_id', widget.quiz.id!);
      }
    } catch (e) {
      debugPrint('❌ Error saving progress: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_locked) _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_locked &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      _saveProgress();
    }
  }

  void _next() {
    final currentQ = widget.quiz.questions[_current];
    final correctLetter = currentQ.correctChoice;
    final selectedLetter = ['A', 'B', 'C'][_selected];
    final isCorrect = selectedLetter == correctLetter;

    setState(() {
      _answered = true;
      if (isCorrect) _score++;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (_current < widget.quiz.questions.length - 1) {
        setState(() {
          _current++;
          _selected = -1;
          _answered = false;
        });
      } else {
        _finishQuiz();
      }
    });
  }

  void _finishQuiz() async {
    if (_locked) return;
    _timer.cancel();
    await _saveProgress();
    setState(() => _quizFinished = true);
    _animationController.forward();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 400),
      barrierLabel: 'Quiz Result',
      pageBuilder: (context, _, __) {
        return Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildResultDialog(),
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildResultDialog() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700], size: 48),
            const SizedBox(height: 16),
            const Text('Quiz Complete!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Your score: $_score / ${widget.quiz.questions.length}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentDashboard()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return Scaffold(
        appBar: AppBar(title: const Text("Quiz Locked")),
        body: const Center(
          child: Text(
            "You have already used all 3 attempts.\nYour highest score is saved.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (_quizFinished) return const SizedBox.shrink();

    final currentQ = widget.quiz.questions[_current];
    final options = [currentQ.choiceA, currentQ.choiceB, currentQ.choiceC];
    final correctLetter = currentQ.correctChoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        backgroundColor: Colors.lightBlue,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.timer, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ]),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Question ${_current + 1} of ${widget.quiz.questions.length}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          Text(currentQ.questionText,
              style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ...List.generate(options.length, (i) {
            final letter = ['A', 'B', 'C'][i];
            Color cardColor = Colors.white;

            if (_answered) {
              if (letter == correctLetter) cardColor = Colors.greenAccent;
              else if (_selected == i) cardColor = Colors.redAccent;
            } else if (_selected == i) cardColor = Colors.orangeAccent;

            return Card(
              color: cardColor,
              child: ListTile(
                title: Text('$letter. ${options[i]}'),
                onTap: _answered
                    ? null
                    : () => setState(() {
                  _selected = i;
                }),
              ),
            );
          }),
          const Spacer(),
          ElevatedButton(
            onPressed: (_selected == -1 || _answered) ? null : _next,
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
            child: Text(_current == widget.quiz.questions.length - 1
                ? 'Finish'
                : 'Next'),
          ),
        ]),
      ),
    );
  }
}
