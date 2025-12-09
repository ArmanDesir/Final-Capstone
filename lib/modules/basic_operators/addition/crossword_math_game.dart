import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pracpro/modules/basic_operators/addition/crossword_cell.dart';
import 'package:pracpro/modules/basic_operators/addition/crossword_grid_generator.dart';
import 'package:pracpro/modules/basic_operators/addition/game_theme.dart';
import 'package:pracpro/services/activity_progress_service.dart';
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
  bool _answersChecked = false; 
  int _correct = 0;
  int _totalBlanks = 0;
  bool _isLoading = true;

  final Map<String, TextEditingController> _controllers = {};
  final supabase = Supabase.instance.client;
  final _activityProgressService = ActivityProgressService();
  bool _progressSaved = false; // Track if progress has been saved
  
  // Store game metadata when game starts - reuse for all attempts (including Try Again)
  String? _gameId;
  String _gameTitle = 'Crossword Math';
  bool _gameMetadataLoaded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final min = widget.config?['min'] ?? 1;
    final max = widget.config?['max'] ?? 10;
    final timeSec = 120;

    // Load game metadata ONCE when game starts - reuse for all attempts
    if (!_gameMetadataLoaded) {
      await _loadGameMetadata();
    }

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
        final gridData = puzzle['grid'] as List;
        _grid = gridData
            .map((r) => (r as List)
            .map((c) => CrosswordCell.fromJson(c as Map<String, dynamic>))
            .toList())
            .toList();
      } else {
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

  /// Load game metadata once when game starts
  /// This ensures all attempts (including Try Again) use the same gameId/gameTitle
  /// IMPORTANT: Always use null gameId for Crossword Math to prevent mixing with other games
  /// This ensures Crossword Math groups by title+difficulty+operator, not by entity_id
  Future<void> _loadGameMetadata() async {
    if (_gameMetadataLoaded) return; // Don't reload
    
    // For Crossword Math, always use null gameId and rely on title-based grouping
    // This prevents mixing with other games (like "ywv") that have entity_id
    // All Crossword Math attempts will group by: "Crossword Math|easy|addition"
    _gameId = null;
    _gameTitle = 'Crossword Math';
    _gameMetadataLoaded = true;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_answersChecked || _finished) {
        _timer?.cancel();
        return;
      }
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
            final studentAnswer = int.tryParse(cell.value ?? '');
          
          if (studentAnswer == null) {
              cell.isCorrect = false;
            continue;
            }

          final isEquationCorrect = _validateEquationWithStudentInput(cell, studentAnswer);

          if (isEquationCorrect) {
                cell.isCorrect = true;
                ok++;
              } else {
                cell.isCorrect = false;
              }
        }
      }
    }

    return ok;
  }

  bool _validateEquationWithStudentInput(CrosswordCell blankCell, int studentValue) {
    final row = blankCell.row;
    final col = blankCell.col;

    if (col + 4 < _grid[row].length) {
      final opCell = _getCell(row, col + 1);
      final num2Cell = _getCell(row, col + 2);
      final eqCell = _getCell(row, col + 3);
      final answerCell = _getCell(row, col + 4);

      if (opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num2 = _getNumericValue(num2Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num2 != null && answer != null && op != null) {
          final calculated = _calculateAnswer(studentValue, num2, op);
          if (calculated == answer) {
            return true;
          }
        }
      }
    }

    if (col >= 2 && col + 2 < _grid[row].length) {
      final num1Cell = _getCell(row, col - 2);
      final opCell = _getCell(row, col - 1);
      final eqCell = _getCell(row, col + 1);
      final answerCell = _getCell(row, col + 2);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num1 = _getNumericValue(num1Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num1 != null && answer != null && op != null) {
          final calculated = _calculateAnswer(num1, studentValue, op);
          if (calculated == answer) {
            return true;
          }
        }
      }
    }

    if (col >= 4) {
      final num1Cell = _getCell(row, col - 4);
      final opCell = _getCell(row, col - 3);
      final num2Cell = _getCell(row, col - 2);
      final eqCell = _getCell(row, col - 1);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals) {
        final num1 = _getNumericValue(num1Cell);
        final num2 = _getNumericValue(num2Cell);
        final op = opCell!.value;

        if (num1 != null && num2 != null && op != null) {
          final calculated = _calculateAnswer(num1, num2, op);
          if (calculated == studentValue) {
            return true;
          }
        }
      }
    }

    if (row + 4 < _grid.length) {
      final opCell = _getCell(row + 1, col);
      final num2Cell = _getCell(row + 2, col);
      final eqCell = _getCell(row + 3, col);
      final answerCell = _getCell(row + 4, col);

      if (opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num2 = _getNumericValue(num2Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num2 != null && answer != null && op != null) {
          final calculated = _calculateAnswer(studentValue, num2, op);
          if (calculated == answer) {
            return true;
          }
        }
      }
    }

    if (row >= 2 && row + 2 < _grid.length) {
      final num1Cell = _getCell(row - 2, col);
      final opCell = _getCell(row - 1, col);
      final eqCell = _getCell(row + 1, col);
      final answerCell = _getCell(row + 2, col);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num1 = _getNumericValue(num1Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num1 != null && answer != null && op != null) {
          final calculated = _calculateAnswer(num1, studentValue, op);
          if (calculated == answer) {
            return true;
          }
        }
      }
    }

    if (row >= 4) {
      final num1Cell = _getCell(row - 4, col);
      final opCell = _getCell(row - 3, col);
      final num2Cell = _getCell(row - 2, col);
      final eqCell = _getCell(row - 1, col);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals) {
        final num1 = _getNumericValue(num1Cell);
        final num2 = _getNumericValue(num2Cell);
        final op = opCell!.value;

        if (num1 != null && num2 != null && op != null) {
          final calculated = _calculateAnswer(num1, num2, op);
          if (calculated == studentValue) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _hasNumericValue(CrosswordCell? cell) {
    if (cell == null) return false;
    if (cell.type == CellType.number || cell.type == CellType.answer) {
      return cell.value != null && cell.value!.isNotEmpty;
    }
    if (cell.type == CellType.blank) {
      return cell.value != null && cell.value!.isNotEmpty && int.tryParse(cell.value!) != null;
    }
    return false;
  }

  int? _getNumericValue(CrosswordCell? cell) {
    if (cell == null) return null;
    if (cell.type == CellType.number || cell.type == CellType.answer) {
      return int.tryParse(cell.value ?? '');
    }
    if (cell.type == CellType.blank) {
      return int.tryParse(cell.value ?? '');
    }
    return null;
  }

  int? _checkPatternForBlankCell(CrosswordCell blankCell) {
    final row = blankCell.row;
    final col = blankCell.col;

    if (col + 4 < _grid[row].length) {
      final opCell = _getCell(row, col + 1);
      final num2Cell = _getCell(row, col + 2);
      final eqCell = _getCell(row, col + 3);
      final answerCell = _getCell(row, col + 4);

      if (opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num2 = _getNumericValue(num2Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num2 != null && answer != null && op != null) {
          return _calculateReverseAnswer(answer, num2, op, isFirst: true);
        }
      }
    }

    if (col >= 2 && col + 2 < _grid[row].length) {
      final num1Cell = _getCell(row, col - 2);
      final opCell = _getCell(row, col - 1);
      final eqCell = _getCell(row, col + 1);
      final answerCell = _getCell(row, col + 2);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num1 = _getNumericValue(num1Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num1 != null && answer != null && op != null) {
          return _calculateReverseAnswer(answer, num1, op, isFirst: false);
        }
      }
    }

    if (col >= 4) {
      final num1Cell = _getCell(row, col - 4);
      final opCell = _getCell(row, col - 3);
      final num2Cell = _getCell(row, col - 2);
      final eqCell = _getCell(row, col - 1);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals) {
        final num1 = _getNumericValue(num1Cell);
        final num2 = _getNumericValue(num2Cell);
        final op = opCell!.value;

        if (num1 != null && num2 != null && op != null) {
          return _calculateAnswer(num1, num2, op);
        }
      }
    }

    if (row + 4 < _grid.length) {
      final opCell = _getCell(row + 1, col);
      final num2Cell = _getCell(row + 2, col);
      final eqCell = _getCell(row + 3, col);
      final answerCell = _getCell(row + 4, col);

      if (opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num2 = _getNumericValue(num2Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num2 != null && answer != null && op != null) {
          return _calculateReverseAnswer(answer, num2, op, isFirst: true);
        }
      }
    }

    if (row >= 2 && row + 2 < _grid.length) {
      final num1Cell = _getCell(row - 2, col);
      final opCell = _getCell(row - 1, col);
      final eqCell = _getCell(row + 1, col);
      final answerCell = _getCell(row + 2, col);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          eqCell?.type == CellType.equals &&
          _hasNumericValue(answerCell)) {
        final num1 = _getNumericValue(num1Cell);
        final answer = _getNumericValue(answerCell);
        final op = opCell!.value;

        if (num1 != null && answer != null && op != null) {
          return _calculateReverseAnswer(answer, num1, op, isFirst: false);
        }
      }
    }

    if (row >= 4) {
      final num1Cell = _getCell(row - 4, col);
      final opCell = _getCell(row - 3, col);
      final num2Cell = _getCell(row - 2, col);
      final eqCell = _getCell(row - 1, col);

      if (_hasNumericValue(num1Cell) &&
          opCell?.type == CellType.operator &&
          _hasNumericValue(num2Cell) &&
          eqCell?.type == CellType.equals) {
        final num1 = _getNumericValue(num1Cell);
        final num2 = _getNumericValue(num2Cell);
        final op = opCell!.value;

        if (num1 != null && num2 != null && op != null) {
          return _calculateAnswer(num1, num2, op);
        }
      }
    }

    return null;
  }

  int? _calculateReverseAnswer(int answer, int knownOperand, String op, {required bool isFirst}) {
    switch (op) {
      case '+':
        return answer - knownOperand;
      case '-':
        if (isFirst) {
          return answer + knownOperand;
        } else {
          return knownOperand - answer;
        }
      case '×':
      case '*':
        if (knownOperand != 0 && answer % knownOperand == 0) {
          return answer ~/ knownOperand;
        }
        return null;
      case '÷':
      case '/':
        if (isFirst) {
          return answer * knownOperand;
        } else {
          return knownOperand ~/ answer;
        }
      default:
        return null;
    }
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
    // Prevent duplicate saves for the same attempt
    if (_progressSaved) return;
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Ensure game metadata is loaded (should be loaded in _bootstrap, but double-check)
      if (!_gameMetadataLoaded) {
        await _loadGameMetadata();
      }

      // Use stored gameId and gameTitle - ensures consistency across all attempts
      // This is critical for "Try Again" - all attempts must use the same game metadata

      // Get classroom_id if not provided - try to get from user's current classroom
      String? finalClassroomId = widget.classroomId;
      if (finalClassroomId == null || finalClassroomId.isEmpty) {
        try {
          final classroomsResponse = await supabase
              .from('user_classrooms')
              .select('classroom_id')
              .eq('user_id', user.id)
              .eq('status', 'accepted')
              .order('joined_at', ascending: false)
              .limit(1);
          
          if (classroomsResponse.isNotEmpty) {
            finalClassroomId = classroomsResponse.first['classroom_id'] as String?;
          }
    } catch (e) {
          // If we can't get classroom_id, continue without it
        }
      }

      // Save to unified activity_progress table
      // IMPORTANT: Use stored _gameId and _gameTitle to ensure all attempts
      // (including Try Again) are grouped under the same game
      await _activityProgressService.saveGameProgress(
        userId: user.id,
        gameId: _gameId, // Use stored gameId from initialization
        gameTitle: _gameTitle, // Use stored gameTitle from initialization
        operator: widget.operator,
        difficulty: widget.difficulty.toLowerCase(),
        score: score,
        totalItems: _totalBlanks,
        status: score == _totalBlanks ? 'completed' : 'incomplete',
        elapsedTime: elapsed,
        classroomId: finalClassroomId,
      );
      
      _progressSaved = true; // Mark as saved to prevent duplicates
    } catch (e) {
      // Log error but don't block UI
    }
  }

  void _checkAnswers() async {
    if (_answersChecked) return;
    
    HapticFeedback.lightImpact();
    final ok = _countCorrect();
    
    _timer?.cancel();
    
    setState(() {
      _correct = ok;
      _answersChecked = true;
    });

    final elapsed = 120 - _remainingSeconds;
    // Save progress immediately when answers are checked
    // This ensures it's saved regardless of which button the user clicks
    await _recordGameProgress(ok, elapsed);

    // Show dialog after saving
    _showResultDialog();
  }

  void _showResultDialog() {
    final elapsed = 120 - _remainingSeconds;
    final wrongCount = _totalBlanks - _correct;
    
    List<String> wrongAnswers = [];
    for (int r = 0; r < _grid.length; r++) {
      for (int c = 0; c < _grid[r].length; c++) {
        final cell = _grid[r][c];
        if (cell.type == CellType.blank && !cell.isCorrect && cell.value != null && cell.value!.isNotEmpty) {
          wrongAnswers.add('Cell at row ${r + 1}, col ${c + 1}: "${cell.value}"');
        }
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _correct == _totalBlanks ? Icons.celebration : (_correct > _totalBlanks / 2 ? Icons.thumb_up : Icons.sentiment_neutral),
              color: _correct == _totalBlanks ? Colors.amber : (_correct > _totalBlanks / 2 ? Colors.green : Colors.orange),
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(_correct == _totalBlanks ? 'Amazing!' : 'Nice Work!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Answers submitted! Game is complete.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You got $_correct / $_totalBlanks.',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Time stopped at: ${_fmt(_remainingSeconds)}.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (wrongCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Wrong Answers ($wrongCount):',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...wrongAnswers.take(5).map((answer) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $answer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[900],
                          ),
                        ),
                      )),
                      if (wrongAnswers.length > 5)
                        Text(
                          '... and ${wrongAnswers.length - 5} more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Progress is already saved in _checkAnswers(), but try again if needed
              if (!_progressSaved) {
                _recordGameProgress(_correct, elapsed).then((_) {
                  Navigator.pop(context);
                  setState(() {
                  });
                });
              } else {
                Navigator.pop(context);
                setState(() {
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'View Results',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Progress is already saved in _checkAnswers(), but try again if needed
              if (!_progressSaved) {
                _recordGameProgress(_correct, elapsed).then((_) {
              Navigator.pop(context);
              _reset();
                });
              } else {
                Navigator.pop(context);
                _reset();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Progress is already saved in _checkAnswers(), but try again if needed
              if (!_progressSaved) {
                _recordGameProgress(_correct, elapsed).then((_) {
              Navigator.pop(context);
              Navigator.pop(context, {
                'score': _correct,
                'elapsed': elapsed,
                    'totalBlanks': _totalBlanks, // Include totalBlanks for game_screen
                  });
                });
              } else {
                Navigator.pop(context);
                Navigator.pop(context, {
                  'score': _correct,
                  'elapsed': elapsed,
                  'totalBlanks': _totalBlanks, // Include totalBlanks for game_screen
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _reset() {
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
    
    setState(() {
      // Reset game state for "Try Again"
      // IMPORTANT: DO NOT reset _gameId, _gameTitle, or _gameMetadataLoaded
      // These must persist across attempts to ensure all attempts are grouped correctly
      for (final c in _grid.expand((r) => r)) {
        if (c.type == CellType.blank) {
          c.value = null;
          c.isCorrect = false;
        }
      }
      _correct = 0;
      _finished = false;
      _answersChecked = false;
      _remainingSeconds = 120;
      for (final controller in _controllers.values) {
        controller.clear();
      }
      // Reset progress saved flag so the next attempt can be saved
      _progressSaved = false;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_answersChecked)
              ElevatedButton(
                onPressed: _checkAnswers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text('Check Answers', style: TextStyle(fontSize: 18)),
                    )
                  else ...[
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: const Text('Answers Checked', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        _reset();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: const Text('Try Again', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Correct: $_correct / $_totalBlanks',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _answersChecked
                      ? (_correct == _totalBlanks ? Colors.green : Colors.orange)
                      : Colors.black,
              ),
              ),
              if (_answersChecked) ...[
                const SizedBox(height: 8),
                Text(
                  _correct == _totalBlanks
                      ? 'Perfect! All answers are correct! 🎉'
                      : 'Some answers are incorrect. Check the highlighted cells above.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Timer stopped. Click "Try Again" to restart or use "Go Back" in the dialog.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
    
    Color backgroundColor;
    Color borderColor;
    double borderWidth = 2;
    
    if (_answersChecked) {
      if (cell.isCorrect == true) {
        backgroundColor = Colors.green[100]!;
        borderColor = Colors.green;
      } else if (cell.value != null && cell.value!.isNotEmpty) {
        backgroundColor = Colors.red[100]!;
        borderColor = Colors.red;
      } else {
        backgroundColor = Colors.grey[200]!;
        borderColor = Colors.grey;
      }
    } else {
      backgroundColor = Colors.grey[100]!;
      borderColor = Colors.grey;
    }

    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(GameTheme.borderRadius),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(border: InputBorder.none),
        style: GameTheme.tileText.copyWith(fontSize: 22),
            enabled: !_answersChecked, 
        onChanged: (val) {
              if (!_answersChecked) {
          cell.value = val;
          setState(() {});
              }
            },
          ),
          if (_answersChecked && cell.value != null && cell.value!.isNotEmpty && cell.isCorrect != true)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          if (_answersChecked && cell.isCorrect == true)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
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
