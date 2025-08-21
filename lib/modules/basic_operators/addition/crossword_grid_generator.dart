import 'crossword_cell.dart';
import 'dart:math';

class CrosswordGridGenerator {
  static List<List<CrosswordCell>> getGrid(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return _easyGrid();
      case 'medium':
        return _mediumGrid();
      case 'hard':
        return _hardGrid();
      default:
        return _easyGrid();
    }
  }

  static List<List<CrosswordCell>> _easyGrid() {
    // Simple 5x5 grid with addition only
    // Row 1: 2 + 3 = 5
    // Row 2: + + + = +
    // Row 3: 4 + 1 = 5
    // Row 4: = = = = =
    // Row 5: 6 4 4 = 10

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

  static List<List<CrosswordCell>> _mediumGrid() {
    // 5x5 grid with addition and subtraction
    // Row 1: 8 - 3 = 5
    // Row 2: + - + = +
    // Row 3: 2 + 7 = 9
    // Row 4: = = = = =
    // Row 5: 10 4 10 = 14

    return [
      [
        CrosswordCell(type: CellType.blank, answer: 8),
        CrosswordCell(value: '-', type: CellType.operator),
        CrosswordCell(type: CellType.blank, answer: 3),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '5', type: CellType.answer),
      ],
      [
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(value: '-', type: CellType.operator),
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '+', type: CellType.operator),
      ],
      [
        CrosswordCell(type: CellType.blank, answer: 2),
        CrosswordCell(value: '+', type: CellType.operator),
        CrosswordCell(type: CellType.blank, answer: 7),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '9', type: CellType.answer),
      ],
      [
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
      ],
      [
        CrosswordCell(value: '10', type: CellType.answer),
        CrosswordCell(type: CellType.blank, answer: 4),
        CrosswordCell(value: '10', type: CellType.answer),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '14', type: CellType.answer),
      ],
    ];
  }

  static List<List<CrosswordCell>> _hardGrid() {
    // 5x5 grid with multiplication and division
    // Row 1: 6 ÷ 2 = 3
    // Row 2: × ÷ × = ×
    // Row 3: 4 × 2 = 8
    // Row 4: = = = = =
    // Row 5: 24 4 6 = 11

    return [
      [
        CrosswordCell(type: CellType.blank, answer: 6),
        CrosswordCell(value: '÷', type: CellType.operator),
        CrosswordCell(type: CellType.blank, answer: 2),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '3', type: CellType.answer),
      ],
      [
        CrosswordCell(value: '×', type: CellType.operator),
        CrosswordCell(value: '÷', type: CellType.operator),
        CrosswordCell(value: '×', type: CellType.operator),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '×', type: CellType.operator),
      ],
      [
        CrosswordCell(type: CellType.blank, answer: 4),
        CrosswordCell(value: '×', type: CellType.operator),
        CrosswordCell(type: CellType.blank, answer: 2),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '8', type: CellType.answer),
      ],
      [
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '=', type: CellType.equals),
      ],
      [
        CrosswordCell(value: '24', type: CellType.answer),
        CrosswordCell(type: CellType.blank, answer: 4),
        CrosswordCell(value: '6', type: CellType.answer),
        CrosswordCell(value: '=', type: CellType.equals),
        CrosswordCell(value: '11', type: CellType.answer),
      ],
    ];
  }

  static List<List<CrosswordCell>> _generateRandomGrid(int size) {
    final random = Random();
    List<List<CrosswordCell>> grid = [];

    for (int i = 0; i < size; i++) {
      List<CrosswordCell> row = [];
      for (int j = 0; j < size; j++) {
        if (i == size - 1 || j == size - 1) {
          // Last row and column are equals or answers
          if (i == size - 1 && j == size - 1) {
            row.add(CrosswordCell(value: '=', type: CellType.equals));
          } else if (i == size - 1) {
            row.add(CrosswordCell(value: '=', type: CellType.equals));
          } else {
            row.add(CrosswordCell(value: '=', type: CellType.equals));
          }
        } else if (i % 2 == 0 && j % 2 == 0) {
          // Even positions are numbers (blanks or given)
          int answer = random.nextInt(9) + 1;
          if (random.nextBool()) {
            row.add(CrosswordCell(type: CellType.blank, answer: answer));
          } else {
            row.add(
              CrosswordCell(value: answer.toString(), type: CellType.number),
            );
          }
        } else {
          // Odd positions are operators
          List<String> operators = ['+', '-', '×', '÷'];
          String op = operators[random.nextInt(operators.length)];
          row.add(CrosswordCell(value: op, type: CellType.operator));
        }
      }
      grid.add(row);
    }

    return grid;
  }
}
