import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'crossword_cell.dart';
import 'crossword_grid_generator.dart';
import 'game_theme.dart';

class CrosswordMathGameScreen extends StatefulWidget {
  final String difficulty;
  const CrosswordMathGameScreen({super.key, required this.difficulty});

  @override
  State<CrosswordMathGameScreen> createState() => _CrosswordMathGameScreenState();
}

class _CrosswordMathGameScreenState extends State<CrosswordMathGameScreen> {
  late int _remainingSeconds;
  Timer? _timer;

  late List<List<CrosswordCell>> _grid;
  late List<BankNumber> _bank;

  bool _finished = false;
  int _correct = 0;
  int _totalBlanks = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _bootstrap() {
    final gen = CrosswordGridGenerator.additionGrid(widget.difficulty);
    _grid = gen.grid;
    _bank = gen.bank;

    _totalBlanks = _grid
        .expand((r) => r)
        .where((c) => c.type == CellType.blank)
        .length;
    _remainingSeconds = CrosswordGridGenerator.timers(widget.difficulty)['timeSec']!;
    _startTimer();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    _timer?.cancel();
    setState(() => _finished = true);
    _correct = _countCorrect();
    _showResultDialog();
  }

  int _countCorrect() {
    int ok = 0;
    for (final cell in _grid.expand((r) => r)) {
      if (cell.type == CellType.blank && cell.value != null) {
        final v = int.tryParse(cell.value!);
        if (v != null && v == cell.answer) ok++;
      }
    }
    return ok;
  }

  void _checkAnswers() {
    HapticFeedback.lightImpact();

    int ok = 0;
    for (final cell in _grid.expand((r) => r)) {
      if (cell.type == CellType.blank) {
        final v = int.tryParse(cell.value ?? '');
        final correct = (v != null && v == cell.answer);
        cell.isCorrect = correct;
        if (correct) ok++;
      }
    }
    setState(() => _correct = ok);
    _showResultDialog();
  }

  void _showResultDialog() {
    final elapsed = CrosswordGridGenerator.timers(widget.difficulty)['timeSec']! - _remainingSeconds;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(_correct == _totalBlanks ? 'Amazing!' : 'Nice Work!'),
        content: Text('You got $_correct / $_totalBlanks.\nTime: ${_fmt(_remainingSeconds)} left.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _reset(); },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {'score': _correct, 'elapsed': elapsed});
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
      for (final b in _bank) { b.used = false; }
      _correct = 0;
      _finished = false;
      _remainingSeconds = CrosswordGridGenerator.timers(widget.difficulty)['timeSec']!;
      _startTimer();
    });
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final timeText = _fmt(_remainingSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.difficulty} CrossMath'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(timeText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

              const Text('Drag numbers to fill the blanks:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
              const SizedBox(height: 12),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final n in _bank.where((b) => !b.used))
                    _draggableNumber(n),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _checkAnswers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text('Check Answers', style: TextStyle(fontSize: 18)),
              ),

              const SizedBox(height: 8),
              Text('Correct: $_correct / $_totalBlanks', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(CrosswordCell cell) {
    switch (cell.type) {
      case CellType.blank:
        return _dropTarget(cell);
      default:
        return _staticTile(cell);
    }
  }

  Widget _dropTarget(CrosswordCell cell) {
    return DragTarget<BankNumber>(
      onWillAccept: (data) => true,
      onAccept: (data) {
        setState(() {
          final prev = int.tryParse(cell.value ?? '');
          if (prev != null) {
            final maybe = _bank.firstWhere(
                  (b) => b.value == prev && b.used == true,
              orElse: () => BankNumber(id: -1, value: -1, used: false),
            );
            if (maybe.id != -1) maybe.used = false;
          }
          cell.value = data.value.toString();
          data.used = true;
          cell.isCorrect = (cell.answer == data.value);
          HapticFeedback.selectionClick();
        });
      },
      builder: (context, cand, rej) {
        final hovered = cand.isNotEmpty;
        final border = cell.isCorrect ? GameTheme.correct : (hovered ? Colors.blue : Colors.grey);
        final fill   = cell.isCorrect ? Colors.green[100] : (hovered ? Colors.blue[50] : Colors.grey[100]);
        return Container(
          width: 60, height: 60, margin: const EdgeInsets.all(4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(GameTheme.borderRadius),
            border: Border.all(color: border, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Text(cell.value ?? '', style: GameTheme.tileText),
        );
      },
    );
  }

  Widget _staticTile(CrosswordCell cell) {
    Color bg, fg;
    switch (cell.type) {
      case CellType.operator: bg = Colors.blue[100]!;  fg = Colors.blue[800]!; break;
      case CellType.equals:   bg = Colors.green[100]!; fg = Colors.green[800]!; break;
      case CellType.number:
      case CellType.answer:   bg = Colors.purple[100]!; fg = Colors.purple[800]!; break;
      default:                bg = Colors.white;       fg = Colors.black;
    }
    return Container(
      width: 60, height: 60, margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GameTheme.borderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(cell.value ?? '', style: GameTheme.tileText.copyWith(color: fg)),
    );
  }

  Widget _draggableNumber(BankNumber n) {
    final chip = Container(
      width: 60, height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text('${n.value}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );

    return LongPressDraggable<BankNumber>(
      data: n,
      feedback: Material(color: Colors.transparent, child: chip),
      childWhenDragging: Opacity(opacity: .35, child: chip),
      child: chip,
      onDragStarted: () => HapticFeedback.lightImpact(),
    );
  }
}
