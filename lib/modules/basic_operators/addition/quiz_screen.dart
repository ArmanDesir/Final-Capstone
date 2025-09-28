import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final String quizId;
  final String userId;

  const QuizScreen({
    Key? key,
    required this.questions,
    required this.quizId,
    required this.userId,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selected = -1;
  int _score = 0;
  int _current = 0;
  bool _quizFinished = false;
  bool _locked = false;
  late Timer _timer;
  int _remainingSeconds = 300;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
      final res = await Supabase.instance.client
          .from('quiz_progress')
          .select()
          .eq('user_id', widget.userId)
          .eq('quiz_id', widget.quizId)
          .maybeSingle();

      if (res != null) {
        int count = 0;
        if (res['try1score'] != null) count++;
        if (res['try2score'] != null) count++;
        if (res['try3score'] != null) count++;
        if (count >= 3) {
          setState(() => _locked = true);
          return;
        }
      }
      _startTimer();
    } catch (e) {
      debugPrint("Error checking attempts: $e");
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finishQuiz();
      }
    });
  }

  Future<void> _saveProgress() async {
    try {
      await Supabase.instance.client.from('quiz_progress').upsert({
        'user_id': widget.userId,
        'quiz_id': widget.quizId,
        'highest_score': _score,
      });
    } catch (e) {
      debugPrint("Error saving progress: $e");
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
    if (_selected == widget.questions[_current]['a']) _score++;
    if (_current < widget.questions.length - 1) {
      setState(() {
        _current++;
        _selected = -1;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() async {
    if (_locked) return;
    _timer.cancel();
    await _saveProgress();
    setState(() {
      _quizFinished = true;
    });
    _animationController.forward();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Quiz Result',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildResultDialog(),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _feedbackMessage() {
    final total = widget.questions.length;
    final percent = _score / total;
    if (_score == total) {
      return "Perfect! You're a math star!";
    } else if (percent >= 0.8) {
      return "Awesome job! Just a little more!";
    } else if (percent >= 0.6) {
      return "You're doing great! Small push!";
    } else if (percent >= 0.4) {
      return "Keep practicing, you can do it!";
    } else {
      return "Don't give up! Try again!";
    }
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
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700], size: 48),
            const SizedBox(height: 16),
            const Text(
              'Quiz Complete!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your score: $_score/${widget.questions.length}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _feedbackMessage(),
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text('Time left: ${_formatTime(_remainingSeconds)}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
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

    if (_quizFinished) {
      return const SizedBox.shrink();
    }

    final q = widget.questions[_current];

    return WillPopScope(
      onWillPop: () async {
        final quit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Quit Quiz?"),
            content: const Text(
                "If you leave now, your current attempt will be recorded."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Quit")),
            ],
          ),
        );
        if (quit == true) {
          await _saveProgress();
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Addition Quiz'),
          backgroundColor: Colors.green,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${_current + 1} of ${widget.questions.length}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                q['q'],
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ...List.generate(
                (q['options'] as List).length,
                    (i) => Card(
                  color: _selected == i ? Colors.orangeAccent : Colors.white,
                  child: ListTile(
                    title: Text(q['options'][i]),
                    onTap: () => setState(() => _selected = i),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selected == -1 ? null : _next,
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  _current == widget.questions.length - 1
                      ? 'Finish'
                      : 'Next',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
