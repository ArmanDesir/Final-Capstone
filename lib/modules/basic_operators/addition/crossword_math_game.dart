import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pracpro/modules/basic_operators/addition/crossword_cell.dart';
import 'package:pracpro/modules/basic_operators/addition/crossword_grid_generator.dart';
import 'package:pracpro/modules/basic_operators/addition/game_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CrosswordMathGameScreen extends StatefulWidget {
  final String operator;
  final String difficulty;
  final Map<String, dynamic>? config;
  final String? classroomId;

  const CrosswordMathGameScreen({
    super.key,
    required this.operator,
    required this.difficulty,
    this.config,
    this.classroomId,
  });

  @override
  State<CrosswordMathGameScreen> createState() =>
      _CrosswordMathGameScreenState();
}

class _CrosswordMathGameScreenState extends State<CrosswordMathGameScreen> {
  late int _remainingSeconds;
  Timer? _timer;

  late List<List<CrosswordCell>> _grid;
  bool _finished = false;
  int _correct = 0;
  int _totalBlanks = 0;
  bool _isLoading = true;

  final Map<String, TextEditingController> _controllers = {};
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final min = widget.config?['min'] ?? 1;
    final max = widget.config?['max'] ?? 10;
    final timeSec = widget.config?['timeSec'] ?? 180;

    try {
      final puzzle = await supabase
          .from('crossword_puzzles')
          .select()
          .eq('operator', widget.operator)
          .eq('difficulty', widget.difficulty.toLowerCase())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (puzzle != null) {
        debugPrint('🧩 Loaded puzzle for ${widget.operator} (${widget.difficulty})');
        final gridData = puzzle['grid'] as List;
        _grid = gridData
            .map((r) => (r as List)
            .map((c) => CrosswordCell.fromJson(c as Map<String, dynamic>))
            .toList())
            .toList();
      } else {
        debugPrint('⚙️ No puzzle found, generating random...');
        final gen = CrosswordGridGenerator.generate(
          operator: widget.operator,
          difficulty: widget.difficulty,
          minVal: min,
          maxVal: max,
        );
        _grid = gen.grid;
      }

      _totalBlanks =
          _grid.expand((r) => r).where((c) => c.type == CellType.blank).length;

      _remainingSeconds = timeSec;
      _isLoading = false;
      _startTimer();
      setState(() {});
    } catch (e, st) {
      debugPrint('❌ Failed to load puzzle: $e\n$st');
      final gen = CrosswordGridGenerator.generate(
        operator: widget.operator,
        difficulty: widget.difficulty,
        minVal: min,
        maxVal: max,
      );
      _grid = gen.grid;
      _remainingSeconds = timeSec;
      _isLoading = false;
      _startTimer();
      setState(() {});
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    setState(() => _finished = true);
    _correct = _countCorrect();
    _showResultDialog();
  }

  int _countCorrect() {
    int ok = 0;
    for (final row in _grid) {
      final numCell = row.firstWhere(
            (c) => c.type == CellType.number,
        orElse: () => CrosswordCell(row: -1, col: -1, type: CellType.empty),
      );
      final opCell = row.firstWhere(
            (c) => c.type == CellType.operator,
        orElse: () => CrosswordCell(row: -1, col: -1, type: CellType.empty),
      );
      final blankCell = row.firstWhere(
            (c) => c.type == CellType.blank,
        orElse: () => CrosswordCell(row: -1, col: -1, type: CellType.empty),
      );
      final ansCell = row.firstWhere(
            (c) => c.type == CellType.answer,
        orElse: () => CrosswordCell(row: -1, col: -1, type: CellType.empty),
      );

      if (blankCell.row == -1) continue;

      final left = int.tryParse(numCell.value ?? '');
      final right = int.tryParse(blankCell.value ?? '');
      final expected = int.tryParse(ansCell.value ?? '');
      final op = opCell.value;

      if (left == null || right == null || expected == null || op == null) continue;

      bool correct = false;
      switch (op) {
        case '+':
          correct = (left + right == expected);
          break;
        case '-':
          correct = (left - right == expected);
          break;
        case '×':
        case '*':
          correct = (left * right == expected);
          break;
        case '÷':
        case '/':
          if (right != 0) correct = (left / right == expected);
          break;
      }

      blankCell.isCorrect = correct;
      if (correct) ok++;
    }
    return ok;
  }

  Future<void> _recordGameProgress(int score, int elapsed) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final gameName = '${widget.operator}_crossmath';
      final difficulty = widget.difficulty.toLowerCase();
      final status = score == _totalBlanks ? 'completed' : 'incomplete';
      final sourceId = const Uuid().v4();

      await supabase.from('game_progress').insert({
        'user_id': user.id,
        'game_name': gameName,
        'difficulty': difficulty,
        'score': score,
        'elapsed_time': elapsed,
        'status': status,
        'tries': 1,
      });

      if (widget.classroomId != null) {
        await supabase.from('activity_progress_by_classroom').insert({
          'source': 'game',
          'source_id': sourceId,
          'user_id': user.id,
          'entity_type': 'crossmath',
          'entity_id': null,
          'entity_title': gameName,
          'stage': difficulty,
          'score': score,
          'status': status,
          'classroom_id': widget.classroomId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      debugPrint('✅ Progress saved: $score / $_totalBlanks');
    } catch (e) {
      debugPrint('❌ Failed to record progress: $e');
    }
  }

  void _checkAnswers() async {
    HapticFeedback.lightImpact();
    final ok = _countCorrect();
    setState(() => _correct = ok);

    final elapsed = (widget.config?['timeSec'] ?? 180) - _remainingSeconds;
    await _recordGameProgress(ok, elapsed);

    _showResultDialog();
  }

  void _showResultDialog() {
    final elapsed = (widget.config?['timeSec'] ?? 180) - _remainingSeconds;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(_correct == _totalBlanks ? 'Amazing!' : 'Nice Work!'),
        content: Text(
          'You got $_correct / $_totalBlanks.\nTime left: ${_fmt(_remainingSeconds)}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reset();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {
                'score': _correct,
                'elapsed': elapsed,
              });
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      for (final c in _grid.expand((r) => r)) {
        if (c.type == CellType.blank) {
          c.value = null;
          c.isCorrect = false;
        }
      }
      _correct = 0;
      _finished = false;
      _remainingSeconds = widget.config?['timeSec'] ?? 180;
      _startTimer();
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final timeText = _fmt(_remainingSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.operator[0].toUpperCase()}${widget.operator.substring(1)} - ${widget.difficulty} CrossMath',
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                timeText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              for (int r = 0; r < _grid.length; r++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int c = 0; c < _grid[r].length; c++)
                      _buildCell(_grid[r][c]),
                  ],
                ),
              const SizedBox(height: 24),
              _buildLegend(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkAnswers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text('Check Answers', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 8),
              Text(
                'Correct: $_correct / $_totalBlanks',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        const Text(
          '🧭 LEGEND',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _legendTile(Colors.purple[100]!, 'Given Number / Answer'),
            _legendTile(Colors.blue[100]!, 'Operator (+, -, ×, ÷)'),
            _legendTile(Colors.green[100]!, 'Equal (=)'),
            _legendTile(Colors.grey[100]!, 'Your Answer (type here)'),
          ],
        ),
      ],
    );
  }

  Widget _legendTile(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildCell(CrosswordCell cell) {
    switch (cell.type) {
      case CellType.blank:
        return _editableCell(cell);
      default:
        return _staticTile(cell);
    }
  }

  Widget _editableCell(CrosswordCell cell) {
    final key = '${cell.row}-${cell.col}';
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: cell.value ?? '');
    }
    final controller = _controllers[key]!;

    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cell.isCorrect == true ? Colors.green[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(GameTheme.borderRadius),
        border: Border.all(
          color: cell.isCorrect == true ? GameTheme.correct : Colors.grey,
          width: 2,
        ),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(border: InputBorder.none),
        style: GameTheme.tileText.copyWith(fontSize: 22),
        onChanged: (val) {
          cell.value = val;
          setState(() {});
        },
      ),
    );
  }

  Widget _staticTile(CrosswordCell cell) {
    Color bg, fg;
    switch (cell.type) {
      case CellType.operator:
        bg = Colors.blue[100]!;
        fg = Colors.blue[800]!;
        break;
      case CellType.equals:
        bg = Colors.green[100]!;
        fg = Colors.green[800]!;
        break;
      case CellType.number:
      case CellType.answer:
        bg = Colors.purple[100]!;
        fg = Colors.purple[800]!;
        break;
      default:
        bg = Colors.white;
        fg = Colors.black;
    }
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GameTheme.borderRadius),
      ),
      child: Text(cell.value ?? '', style: GameTheme.tileText.copyWith(color: fg)),
    );
  }
}
