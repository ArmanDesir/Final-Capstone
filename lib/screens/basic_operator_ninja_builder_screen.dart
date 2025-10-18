import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:offline_first_app/modules/basic_operators/addition/game_theme.dart';
import 'package:offline_first_app/modules/basic_operators/addition/widgets/game_button.dart';

/// 🧠 Ninja Math Builder Screen
/// Teachers can edit target totals; system randomizes valid numbers automatically.
/// Includes per-round validation states (blue → unchecked, green → valid, red → invalid)
class BasicOperatorNinjaBuilderScreen extends StatefulWidget {
  final String operator;
  final Map<String, dynamic> config;
  final String difficulty;
  final String title;
  final String? description;

  const BasicOperatorNinjaBuilderScreen({
    super.key,
    required this.operator,
    required this.config,
    required this.difficulty,
    required this.title,
    this.description,
  });

  @override
  State<BasicOperatorNinjaBuilderScreen> createState() =>
      _BasicOperatorNinjaBuilderScreenState();
}

class _BasicOperatorNinjaBuilderScreenState
    extends State<BasicOperatorNinjaBuilderScreen> {
  late int _totalRounds;
  late int _min;
  late int _max;
  late List<_PreviewRound> _rounds;
  final Random _random = Random();

  late List<TextEditingController> _controllers;
  late List<ValidationState> _validationStates;

  @override
  void initState() {
    super.initState();
    _applyConfig();
    _rounds = _generateValidRounds();
    _controllers = List.generate(
        _rounds.length,
            (i) => TextEditingController(text: _rounds[i].target.toString()));
    _validationStates =
        List.generate(_rounds.length, (_) => ValidationState.unchecked);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyConfig() {
    _totalRounds = widget.config['rounds'] ?? 10;
    _min = widget.config['min'] ?? 1;
    _max = widget.config['max'] ?? 10;
  }

  /// ✅ Generates valid number sets for each target.
  List<_PreviewRound> _generateValidRounds() {
    return List.generate(
        _totalRounds, (_) {
      int target = _min + _random.nextInt((_max * 2) - _min);
      return _generateRoundWithTarget(target);
    });
  }

  /// 🎯 Smart number generator — “answerable if possible” with fallback.
  _PreviewRound _generateRoundWithTarget(int target) {
    int baseCount = 4;
    int maxCount = 6;
    int numCount = baseCount + _random.nextInt(2);

    if (target > _max * 3.5) numCount = maxCount;

    bool solvable = false;
    List<int> numbers = [];

    for (int attempt = 0; attempt < 150 && !solvable; attempt++) {
      numbers =
          List.generate(numCount, (_) => _min + _random.nextInt(_max - _min + 1));
      for (int comboSize = 2; comboSize <= min(5, numbers.length); comboSize++) {
        for (final combo in _getCombinations(numbers, comboSize)) {
          if (combo.reduce((a, b) => a + b) == target) {
            solvable = true;
            break;
          }
        }
        if (solvable) break;
      }
    }
    if (!solvable) {
      int avg = (target / numCount).round().clamp(_min, _max);
      numbers = List.generate(numCount, (_) => avg);
      int total = numbers.reduce((a, b) => a + b);
      int diff = target - total;

      while (diff != 0) {
        int idx = _random.nextInt(numbers.length);
        int candidate = numbers[idx] + diff.sign;
        if (candidate >= _min && candidate <= _max) {
          numbers[idx] = candidate;
          diff -= diff.sign;
        } else {
          break;
        }
      }
    }

    numbers.shuffle();
    return _PreviewRound(target: target, numbers: numbers);
  }

  /// 🔢 Generates all unique n-element combinations of a list.
  List<List<int>> _getCombinations(List<int> items, int length) {
    if (length == 0) return [[]];
    if (items.length < length) return [];

    List<List<int>> result = [];
    for (int i = 0; i < items.length; i++) {
      var head = items[i];
      var tailCombos = _getCombinations(items.sublist(i + 1), length - 1);
      for (var tail in tailCombos) {
        result.add([head, ...tail]);
      }
    }
    return result;
  }

  bool _isTargetValid(int value) {
    const minNumbers = 2;
    const maxNumbers = 5;
    final minPossible = _min * minNumbers;
    final maxPossible = _max * maxNumbers;
    return value >= minPossible && value <= maxPossible;
  }

  void _applyNewTarget(int index) {
    final value = _controllers[index].text.trim();
    final newTarget = int.tryParse(value);
    if (newTarget == null) {
      _showSnack('⚠️ Please enter a valid number.');
      setState(() => _validationStates[index] = ValidationState.invalid);
      return;
    }

    if (!_isTargetValid(newTarget)) {
      _showSnack(
          '⚠️ Total must be between ${_min * 2} and ${_max * 5} (range $_min–$_max).');
      setState(() => _validationStates[index] = ValidationState.invalid);
      return;
    }

    setState(() {
      _rounds[index] = _generateRoundWithTarget(newTarget);
      _controllers[index].text = newTarget.toString();
      _validationStates[index] = ValidationState.valid;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _randomizeRounds() {
    setState(() {
      _rounds = _generateValidRounds();
      for (int i = 0; i < _rounds.length; i++) {
        _controllers[i].text = _rounds[i].target.toString();
        _validationStates[i] = ValidationState.unchecked;
      }
    });
  }

  bool get _allValid =>
      _validationStates.every((state) => state == ValidationState.valid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.background,
      appBar: AppBar(
        backgroundColor: GameTheme.primary,
        title: Text('Preview: ${widget.title} (${widget.difficulty})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: _randomizeRounds,
            tooltip: 'Randomize All Rounds',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _rounds.length,
                itemBuilder: (context, index) =>
                    _buildRoundCard(index, _rounds[index]),
              ),
            ),
            const SizedBox(height: 24),
            GameButton(
              text: 'Looks Good!',
              color: _allValid ? GameTheme.primary : Colors.grey,
              onTap: _allValid
                  ? () {
                Navigator.pop(
                  context,
                  _rounds
                      .map((r) => {
                    'numbers': r.numbers,
                    'target': r.target,
                  })
                      .toList(),
                );
              }
                  : () => _showSnack(
                  '⚠️ Please validate all totals (turn all buttons green).'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: GameTheme.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: GameTheme.tileText.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.description != null)
              Text(widget.description!,
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Difficulty: ${widget.difficulty}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text('Rounds: $_totalRounds | Range: $_min - $_max',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundCard(int index, _PreviewRound round) {
    bool isApplying = false;

    return StatefulBuilder(
      builder: (context, setInner) {
        Color iconColor;
        switch (_validationStates[index]) {
          case ValidationState.valid:
            iconColor = Colors.green;
            break;
          case ValidationState.invalid:
            iconColor = Colors.red;
            break;
          default:
            iconColor = Colors.blue;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Round ${index + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _controllers[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            onTap: () => setState(() =>
                            _validationStates[index] =
                                ValidationState.unchecked),
                            decoration: const InputDecoration(
                              labelText: 'Total',
                              labelStyle: TextStyle(fontSize: 12),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: isApplying
                              ? const SizedBox(
                            height: 16,
                            width: 16,
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Icon(Icons.check_circle, color: iconColor),
                          tooltip: 'Apply',
                          onPressed: isApplying
                              ? null
                              : () async {
                            setInner(() => isApplying = true);
                            await Future.delayed(
                                const Duration(milliseconds: 250));
                            _applyNewTarget(index);
                            setInner(() => isApplying = false);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Valid range: ${_min * 2}–${_max * 5}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: round.numbers
                      .map(
                        (n) => Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$n',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum ValidationState { unchecked, valid, invalid }

class _PreviewRound {
  final int target;
  final List<int> numbers;
  _PreviewRound({required this.target, required this.numbers});
}
