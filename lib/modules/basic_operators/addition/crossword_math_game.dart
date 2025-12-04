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
      for (final cell in row) {
        if (cell.type == CellType.blank) {

          if (cell.answer != null) {

            final studentAnswer = int.tryParse(cell.value ?? '');
            if (studentAnswer != null && studentAnswer == cell.answer) {
              cell.isCorrect = true;
              ok++;
            } else {
              cell.isCorrect = false;
            }
          } else {

            final patternResult = _checkPatternForBlankCell(cell);
            if (patternResult != null) {
              final studentAnswer = int.tryParse(cell.value ?? '');
              if (studentAnswer != null && studentAnswer == patternResult) {
                cell.isCorrect = true;
                ok++;
              } else {
                cell.isCorrect = false;
              }
            } else {
              cell.isCorrect = false;
            }
          }
        }
      }
    }

    return ok;
  }

  int? _checkPatternForBlankCell(CrosswordCell blankCell) {
    final row = blankCell.row;
    final col = blankCell.col;

    if (col >= 4) {
      final num1Cell = _getCell(row, col - 4);
      final opCell = _getCell(row, col - 3);
      final num2Cell = _getCell(row, col - 2);
      final eqCell = _getCell(row, col - 1);

      if (num1Cell?.type == CellType.number &&
          opCell?.type == CellType.operator &&
          num2Cell?.type == CellType.number &&
          eqCell?.type == CellType.equals) {
        final num1 = int.tryParse(num1Cell!.value ?? '');
        final num2 = int.tryParse(num2Cell!.value ?? '');
        final op = opCell!.value;

        if (num1 != null && num2 != null && op != null) {
          return _calculateAnswer(num1, num2, op);
        }
      }
    }

    if (row >= 4) {
      final num1Cell = _getCell(row - 4, col);
      final opCell = _getCell(row - 3, col);
      final num2Cell = _getCell(row - 2, col);
      final eqCell = _getCell(row - 1, col);

      if (num1Cell?.type == CellType.number &&
          opCell?.type == CellType.operator &&
          num2Cell?.type == CellType.number &&
          eqCell?.type == CellType.equals) {
        final num1 = int.tryParse(num1Cell!.value ?? '');
        final num2 = int.tryParse(num2Cell!.value ?? '');
        final op = opCell!.value;

        if (num1 != null && num2 != null && op != null) {
          return _calculateAnswer(num1, num2, op);
        }
      }
    }

    return null;
  }

  CrosswordCell? _getCell(int row, int col) {
    if (row < 0 || row >= _grid.length || col < 0 || col >= _grid[row].length) {
      return null;
    }
    return _grid[row][col];
  }

  int? _calculateAnswer(int num1, int num2, String op) {
    switch (op) {
      case '+':
        return num1 + num2;
      case '-':
        return num1 - num2;
      case '×':
      case '*':
        return num1 * num2;
      case '÷':
      case '/':
        if (num2 != 0) return num1 ~/ num2;
        return null;
      default:
        return null;
    }
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

      debugPrint('✅ Progress saved: $score / $_totalBlanks');
    } catch (e) {

      final errorStr = e.toString();
      if (errorStr.contains('upsert_activity_progress') ||
          errorStr.contains('function') && errorStr.contains('does not exist')) {

        debugPrint('⚠️ Activity progress logging issue (non-critical, game progress saved): $e');
      } else {
        debugPrint('❌ Failed to record progress: $e');
      }
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
