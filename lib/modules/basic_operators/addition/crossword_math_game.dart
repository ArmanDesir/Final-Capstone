import 'package:flutter/material.dart';
import 'dart:async';
import 'package:offline_first_app/modules/basic_operators/addition/crossword_cell.dart';
import 'game_theme.dart';

class CrosswordMathGameScreen extends StatefulWidget {
  final String difficulty;
  const CrosswordMathGameScreen({super.key, required this.difficulty});

  @override
  State<CrosswordMathGameScreen> createState() =>
      _CrosswordMathGameScreenState();
}

class _CrosswordMathGameScreenState extends State<CrosswordMathGameScreen>
    with TickerProviderStateMixin {
  late int _remainingSeconds;
  late Timer _timer;
  bool _gameFinished = false;
  late List<List<CrosswordCell>> _crosswordGrid;
  late List<int> _numberBank;
  late List<int> _usedNumbers;
  int _correct = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _setTimer();
    _setupCrosswordGrid();
    _startTimer();
  }

  void _setTimer() {
    if (widget.difficulty == 'Easy') {
      _remainingSeconds = 300;
    } else if (widget.difficulty == 'Medium') {
      _remainingSeconds = 420;
    } else {
      _remainingSeconds = 600;
    }
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

  void _setupCrosswordGrid() {
    _crosswordGrid = _createMathCrossword();
    _numberBank = [];
    _usedNumbers = [];
    _total = 0;

    for (var row in _crosswordGrid) {
      for (var cell in row) {
        if (cell.type == CellType.blank) {
          _numberBank.add(cell.answer!);
          _total++;
        }
      }
    }

    _numberBank.addAll([1, 2, 7, 8, 9]);
    _numberBank.shuffle();

    _gameFinished = false;
    _correct = 0;
  }

  List<List<CrosswordCell>> _createMathCrossword() {


    return [
      [
        CrosswordCell(type: CellType.blank, answer: 2),
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(type: CellType.blank, answer: 3),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '5', type: CellType.answer),
      ],
      [
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '+', type: CellType.operator),
      ],
      [
        CrosswordCell(type: CellType.blank, answer: 4),
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(type: CellType.blank, answer: 1),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '5', type: CellType.answer),
      ],
      [
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '', type: CellType.empty),
        CrosswordCell(value: '', type: CellType.empty),
        CrosswordCell(value: '=', type: CellType.equals),
      ],
      [
        CrosswordCell(value: '6', type: CellType.answer),
        CrosswordCell(type: CellType.blank, answer: 6),
        CrosswordCell(value: '4', type: CellType.answer),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '10', type: CellType.answer),
      ],
    ];
  }

  void _finishGame() {
    _timer.cancel();
    setState(() => _gameFinished = true);
    int correct = _countCorrectAnswers();
    _showFeedbackDialog(correct, _total);
  }

  int _countCorrectAnswers() {
    int correct = 0;
    for (var row in _crosswordGrid) {
      for (var cell in row) {
        if (cell.type == CellType.blank &&
            cell.value != null &&
            int.tryParse(cell.value!) == cell.answer) {
          correct++;
        }
      }
    }
    return correct;
  }

  void _checkAnswers() {
    int correct = _countCorrectAnswers();
    setState(() {
      _gameFinished = true;
      _correct = correct;
    });
    _showFeedbackDialog(_correct, _total);
  }

  void _showFeedbackDialog(int correct, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text('Great Job!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  correct == total ? Icons.emoji_events : Icons.star,
                  color: correct == total ? Colors.amber : Colors.yellow[700],
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'You got $correct out of $total correct!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  correct == total
                      ? 'Amazing! You solved the puzzle!'
                      : 'Keep practicing and try again!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetGame();
                },
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
    );
  }

  void _resetGame() {
    setState(() {
      for (var row in _crosswordGrid) {
        for (var cell in row) {
          if (cell.type == CellType.blank) {
            cell.value = null;
          }
        }
      }
      _usedNumbers.clear();
      _setupCrosswordGrid();
      _remainingSeconds = widget.difficulty == 'Easy' ? 300 : 420;
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.difficulty} CrossMath'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              for (int i = 0; i < _crosswordGrid.length; i++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int j = 0; j < _crosswordGrid[i].length; j++)
                      _buildGridCell(_crosswordGrid[i][j], i, j),
                  ],
                ),
              const SizedBox(height: 32),

              const Text(
                'Drag numbers to fill the blanks:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < _numberBank.length; i++)
                    if (!_usedNumbers.contains(i))
                      _buildDraggableNumber(_numberBank[i], i),
                ],
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _checkAnswers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Check Answers',
                  style: TextStyle(fontSize: 20),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Correct: $_correct / $_total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCell(CrosswordCell cell, int row, int col) {
    if (cell.type == CellType.blank) {
      return _buildDropTarget(cell, row, col);
    }

    return _buildTile(cell.value ?? '', cell.type);
  }

  Widget _buildDropTarget(CrosswordCell cell, int row, int col) {
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        bool isHovered = candidateData.isNotEmpty;
        return Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isHovered ? Colors.blue[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(GameTheme.borderRadius),
            border: Border.all(
              color: isHovered ? Colors.blue : Colors.grey,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(cell.value ?? '', style: GameTheme.tileText),
        );
      },
      onWillAccept: (data) => cell.value == null,
      onAccept: (data) {
        setState(() {
          cell.value = data.toString();
          _usedNumbers.add(_numberBank.indexOf(data));
        });
      },
    );
  }

  Widget _buildDraggableNumber(int number, int index) {
    return Draggable<int>(
      data: number,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.yellow[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.yellow[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTile(String text, CellType type) {
    Color backgroundColor;
    Color textColor;

    switch (type) {
      case CellType.operator:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case CellType.equals:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case CellType.answer:
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        break;
      default:
        backgroundColor = Colors.white;
        textColor = Colors.black;
    }

    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(GameTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(text, style: GameTheme.tileText.copyWith(color: textColor)),
    );
  }
}
