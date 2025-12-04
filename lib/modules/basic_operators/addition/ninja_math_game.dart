import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'widgets/game_button.dart';
import 'game_theme.dart';

class NinjaMathGameScreen extends StatefulWidget {
  final String difficulty;
  final Map<String, dynamic>? config;
  final String operator;

  const NinjaMathGameScreen({
    super.key,
    required this.difficulty,
    required this.operator,
    this.config,
  });

  @override
  State<NinjaMathGameScreen> createState() => _NinjaMathGameScreenState();
}

class _NinjaMathGameScreenState extends State<NinjaMathGameScreen> {
  late int _remainingSeconds;
  late Timer _timer;
  bool _gameFinished = false;
  int _score = 0;
  int _current = 0;
  late List<_TargetRound> _rounds;
  List<int> _selectedIndices = [];
  late int _totalRounds;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _applyConfig();
    _rounds = _generateRounds();
    _startTimer();
  }

  void _applyConfig() {
    final cfg = widget.config ?? {};
    _remainingSeconds = cfg['timeSec'] ?? 300;
    _totalRounds = cfg['rounds'] ?? 10;

    final active = cfg['activeRounds'];
    if (active != null && active is List) {
      _rounds = _generateRounds()
          .asMap()
          .entries
          .where((entry) => active.contains(entry.key))
          .map((e) => e.value)
          .toList();
    } else {
      _rounds = _generateRounds();
    }
  }

  List<_TargetRound> _generateRounds({List<bool>? enabledFlags}) {
    final cfg = widget.config ?? {};
    final min = cfg['min'] ?? 1;
    final max = cfg['max'] ?? 10;

    List<_TargetRound> list = [];
    for (int i = 0; i < _totalRounds; i++) {
      if (enabledFlags != null && i < enabledFlags.length && !enabledFlags[i]) {
        continue;
      }

      int numCount = 4 + _random.nextInt(2);
      List<int> numbers =
      List.generate(numCount, (_) => min + _random.nextInt(max - min + 1));
      numbers.shuffle();

      int solutionCount = 2 + _random.nextInt(numCount - 1);
      List<int> solution = numbers.sublist(0, solutionCount);
      int target = solution.reduce((a, b) => a + b);
      list.add(_TargetRound(target: target, numbers: numbers));
    }
    return list;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _finishGame();
      }
    });
  }

  void _finishGame() {
    if (_timer.isActive) _timer.cancel();
    setState(() => _gameFinished = true);

    final elapsed = (widget.config?['timeSec'] ?? 300) - _remainingSeconds;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Over!'),
        content: Text(
          'Your score: $_score/$_totalRounds\nTime left: ${_formatTime(_remainingSeconds)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {
                'score': _score,
                'elapsed': elapsed,
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  String _getOperatorSymbol() {
    switch (widget.operator.toLowerCase()) {
      case 'addition':
      case 'add':
        return '+';
      case 'subtraction':
      case 'subtract':
        return '-';
      case 'multiplication':
      case 'multiply':
        return '×';
      case 'division':
      case 'divide':
        return '÷';
      default:
        return '+';
    }
  }

  String _buildCurrentEquation() {
    if (_selectedIndices.isEmpty) {
      return 'No numbers selected';
    }

    final round = _rounds[_current];
    final selectedNumbers = _selectedIndices.map((i) => round.numbers[i]).toList();
    final operator = _getOperatorSymbol();

    return selectedNumbers.join(' $operator ');
  }

  int _calculateCurrentResult() {
    if (_selectedIndices.isEmpty) return 0;

    final round = _rounds[_current];
    final selectedNumbers = _selectedIndices.map((i) => round.numbers[i]).toList();

    switch (widget.operator.toLowerCase()) {
      case 'addition':
      case 'add':
        return selectedNumbers.fold(0, (a, b) => a + b);
      case 'subtraction':
      case 'subtract':
        return selectedNumbers.length > 1
            ? selectedNumbers[0] - selectedNumbers.sublist(1).fold(0, (a, b) => a + b)
            : selectedNumbers[0];
      case 'multiplication':
      case 'multiply':
        return selectedNumbers.fold(1, (a, b) => a * b);
      case 'division':
      case 'divide':
        return selectedNumbers.length > 1
            ? (selectedNumbers[0] / selectedNumbers.sublist(1).fold(1, (a, b) => a * b)).round()
            : selectedNumbers[0];
      default:
        return selectedNumbers.fold(0, (a, b) => a + b);
    }
  }

  void _submit() {
    final round = _rounds[_current];
    int result = _calculateCurrentResult();
    if (result == round.target) _score++;

    if (_current < _totalRounds - 1) {
      setState(() {
        _current++;
        _selectedIndices.clear();
      });
    } else {
      _finishGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gameFinished) return const SizedBox.shrink();
    final round = _rounds[_current];
    final currentEquation = _buildCurrentEquation();
    final currentResult = _calculateCurrentResult();

    return WillPopScope(
      onWillPop: () async {
        final elapsed = (widget.config?['timeSec'] ?? 300) - _remainingSeconds;
        Navigator.pop(context, {
          'score': _score,
          'elapsed': elapsed,
        });
        return false;
      },
      child: Scaffold(
        backgroundColor: GameTheme.background,
        appBar: AppBar(
          title: Text(
            'Ninja Math (${widget.difficulty})',
            style: GameTheme.tileText,
          ),
          backgroundColor: GameTheme.primary,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: GameTheme.tileText.copyWith(
                      color: Colors.white,
                      fontSize: 20,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildMascot(),
              const SizedBox(height: 12),
              _buildTarget(round.target),
              const SizedBox(height: 16),
              Text(
                _selectedIndices.isNotEmpty
                    ? currentEquation
                    : 'No numbers selected',
                style: GameTheme.tileText,
              ),
              const SizedBox(height: 32),
              _buildNumberBank(round.numbers),
              const SizedBox(height: 32),
              GameButton(
                text: 'Submit',
                onTap: _selectedIndices.isNotEmpty ? _submit : () {},
                color: _selectedIndices.isNotEmpty
                    ? GameTheme.primary
                    : GameTheme.tile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMascot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundColor: GameTheme.mascot,
          radius: 28,
          child:
          const Icon(Icons.sports_martial_arts, color: Colors.white, size: 36),
        ),
        const SizedBox(width: 12),
        Text('Be a Math Ninja!', style: GameTheme.mascotText),
      ],
    );
  }

  Widget _buildTarget(int target) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: GameTheme.accent,
        borderRadius: BorderRadius.circular(GameTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Target: $target',
        style: GameTheme.bigNumber.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildNumberBank(List<int> numbers) {
    return Wrap(
      spacing: 16,
      children: List.generate(numbers.length, (index) {
        final n = numbers[index];
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onTap: () => _toggleSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? GameTheme.correct : GameTheme.tileBank,
              borderRadius: BorderRadius.circular(GameTheme.borderRadius),
              border: Border.all(color: GameTheme.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: GameTheme.tileText.copyWith(color: Colors.black),
            ),
          ),
        );
      }),
    );
  }
}

class _TargetRound {
  final int target;
  final List<int> numbers;
  _TargetRound({required this.target, required this.numbers});
}
