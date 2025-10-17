import 'dart:math';
import 'crossword_cell.dart';

class CrosswordGridGenerator {
  static final _rng = Random();

  static const _cfg = {
    'easy': {'min': 1, 'max': 10, 'bankDecoys': 5, 'timeSec': 180},
    'medium': {'min': 1, 'max': 20, 'bankDecoys': 6, 'timeSec': 240},
    'hard': {'min': 1, 'max': 50, 'bankDecoys': 7, 'timeSec': 300},
  };

  static Map<String, int> timers(String difficulty) {
    final d = difficulty.toLowerCase();
    final c = _cfg[d] ?? _cfg['easy']!;
    return {'timeSec': c['timeSec'] as int};
  }

  /// ✅ Main unified generator (handles 4 operators)
  static ({
  List<List<CrosswordCell>> grid,
  List<BankNumber> bank,
  }) generate({
    required String operator,
    required String difficulty,
    int? minVal,
    int? maxVal,
  }) {
    switch (operator.toLowerCase()) {
      case 'addition':
        return additionGrid(difficulty, minVal: minVal, maxVal: maxVal);
      case 'subtraction':
        return subtractionGrid(difficulty, minVal: minVal, maxVal: maxVal);
      case 'multiplication':
        return multiplicationGrid(difficulty, minVal: minVal, maxVal: maxVal);
      case 'division':
        return divisionGrid(difficulty, minVal: minVal, maxVal: maxVal);
      default:
        return additionGrid(difficulty, minVal: minVal, maxVal: maxVal);
    }
  }

 static ({
  List<List<CrosswordCell>> grid,
  List<BankNumber> bank,
  }) additionGrid(
      String difficulty, {
        int? minVal,
        int? maxVal,
      }) {
    final cfg = _cfg[difficulty.toLowerCase()] ?? _cfg['easy']!;
    final minV = minVal ?? cfg['min'] as int;
    final maxV = maxVal ?? cfg['max'] as int;
    final decoys = cfg['bankDecoys'] as int;

    final g = List.generate(
      5,
          (r) => List.generate(
        5,
            (c) => CrosswordCell(row: r, col: c, type: CellType.empty, value: ''),
      ),
    );

    final a = _rnd(minV, maxV);
    final b = _rnd(minV, maxV);
    final c1 = _rnd(minV, maxV);
    final d1 = _rnd(minV, maxV);

    final s1 = a + b;
    final s2 = c1 + d1;
    final s3 = s1 + _rnd(1, 3);
    final s4 = s2 + _rnd(1, 3);
    final s5 = s3 + s4;

    CrosswordCell blank(int r, int c, int ans) =>
        CrosswordCell(row: r, col: c, type: CellType.blank, answer: ans);
    CrosswordCell op(int r, int c, String v) =>
        CrosswordCell(row: r, col: c, type: CellType.operator, value: v);
    CrosswordCell eq(int r, int c) =>
        CrosswordCell(row: r, col: c, type: CellType.equals, value: '=');
    CrosswordCell ans(int r, int c, int v) =>
        CrosswordCell(row: r, col: c, type: CellType.answer, value: '$v');

    g[0] = [blank(0, 0, a), op(0, 1, '+'), blank(0, 2, b), eq(0, 3), ans(0, 4, s1)];
    g[2] = [blank(2, 0, c1), op(2, 1, '+'), blank(2, 2, d1), eq(2, 3), ans(2, 4, s2)];

    final answers = <int>{a, b, c1, d1, s3}.toList();
    final bank = _buildBank(answers, decoys, minV, maxV);
    return (grid: g, bank: bank);
  }

  static ({
  List<List<CrosswordCell>> grid,
  List<BankNumber> bank,
  }) subtractionGrid(
      String difficulty, {
        int? minVal,
        int? maxVal,
      }) {
    final cfg = _cfg[difficulty.toLowerCase()] ?? _cfg['easy']!;
    final minV = minVal ?? cfg['min'] as int;
    final maxV = maxVal ?? cfg['max'] as int;
    final decoys = cfg['bankDecoys'] as int;

    final g = List.generate(
      5,
          (r) => List.generate(
        5,
            (c) => CrosswordCell(row: r, col: c, type: CellType.empty, value: ''),
      ),
    );

    final a = _rnd(minV + 5, maxV);
    final b = _rnd(minV, a);
    final c1 = _rnd(minV + 5, maxV);
    final d1 = _rnd(minVal ?? 1, c1);
    final s1 = a - b;
    final s2 = c1 - d1;

    CrosswordCell blank(int r, int c, int ans) =>
        CrosswordCell(row: r, col: c, type: CellType.blank, answer: ans);
    CrosswordCell op(int r, int c, String v) =>
        CrosswordCell(row: r, col: c, type: CellType.operator, value: v);
    CrosswordCell eq(int r, int c) =>
        CrosswordCell(row: r, col: c, type: CellType.equals, value: '=');
    CrosswordCell ans(int r, int c, int v) =>
        CrosswordCell(row: r, col: c, type: CellType.answer, value: '$v');

    g[0] = [blank(0, 0, a), op(0, 1, '-'), blank(0, 2, b), eq(0, 3), ans(0, 4, s1)];
    g[2] = [blank(2, 0, c1), op(2, 1, '-'), blank(2, 2, d1), eq(2, 3), ans(2, 4, s2)];

    final answers = <int>{a, b, c1, d1, s1, s2}.toList();
    final bank = _buildBank(answers, decoys, minV, maxV);
    return (grid: g, bank: bank);
  }

  static ({
  List<List<CrosswordCell>> grid,
  List<BankNumber> bank,
  }) multiplicationGrid(
      String difficulty, {
        int? minVal,
        int? maxVal,
      }) {
    final cfg = _cfg[difficulty.toLowerCase()] ?? _cfg['easy']!;
    final minV = minVal ?? cfg['min'] as int;
    final maxV = maxVal ?? cfg['max'] as int;
    final decoys = cfg['bankDecoys'] as int;

    final g = List.generate(
      5,
          (r) => List.generate(
        5,
            (c) => CrosswordCell(row: r, col: c, type: CellType.empty, value: ''),
      ),
    );

    final a = _rnd(minV, maxV);
    final b = _rnd(minV, maxV);
    final c1 = _rnd(minV, maxV);
    final d1 = _rnd(minV, maxV);
    final s1 = a * b;
    final s2 = c1 * d1;

    CrosswordCell blank(int r, int c, int ans) =>
        CrosswordCell(row: r, col: c, type: CellType.blank, answer: ans);
    CrosswordCell op(int r, int c, String v) =>
        CrosswordCell(row: r, col: c, type: CellType.operator, value: v);
    CrosswordCell eq(int r, int c) =>
        CrosswordCell(row: r, col: c, type: CellType.equals, value: '=');
    CrosswordCell ans(int r, int c, int v) =>
        CrosswordCell(row: r, col: c, type: CellType.answer, value: '$v');

    g[0] = [blank(0, 0, a), op(0, 1, '×'), blank(0, 2, b), eq(0, 3), ans(0, 4, s1)];
    g[2] = [blank(2, 0, c1), op(2, 1, '×'), blank(2, 2, d1), eq(2, 3), ans(2, 4, s2)];

    final answers = <int>{a, b, c1, d1, s1, s2}.toList();
    final bank = _buildBank(answers, decoys, minV, maxV);
    return (grid: g, bank: bank);
  }

  static ({
  List<List<CrosswordCell>> grid,
  List<BankNumber> bank,
  }) divisionGrid(
      String difficulty, {
        int? minVal,
        int? maxVal,
      }) {
    final cfg = _cfg[difficulty.toLowerCase()] ?? _cfg['easy']!;
    final minV = minVal ?? cfg['min'] as int;
    final maxV = maxVal ?? cfg['max'] as int;
    final decoys = cfg['bankDecoys'] as int;

    final g = List.generate(
      5,
          (r) => List.generate(
        5,
            (c) => CrosswordCell(row: r, col: c, type: CellType.empty, value: ''),
      ),
    );

    int a = _rnd(minV, maxV);
    int b = _rnd(1, 9);
    a = a - (a % b);
    final c1 = _rnd(minV, maxV);
    int d1 = _rnd(1, 9);
    final s1 = (a ~/ b);
    final s2 = (c1 ~/ d1);

    CrosswordCell blank(int r, int c, int ans) =>
        CrosswordCell(row: r, col: c, type: CellType.blank, answer: ans);
    CrosswordCell op(int r, int c, String v) =>
        CrosswordCell(row: r, col: c, type: CellType.operator, value: v);
    CrosswordCell eq(int r, int c) =>
        CrosswordCell(row: r, col: c, type: CellType.equals, value: '=');
    CrosswordCell ans(int r, int c, int v) =>
        CrosswordCell(row: r, col: c, type: CellType.answer, value: '$v');

    g[0] = [blank(0, 0, a), op(0, 1, '÷'), blank(0, 2, b), eq(0, 3), ans(0, 4, s1)];
    g[2] = [blank(2, 0, c1), op(2, 1, '÷'), blank(2, 2, d1), eq(2, 3), ans(2, 4, s2)];

    final answers = <int>{a, b, c1, d1, s1, s2}.toList();
    final bank = _buildBank(answers, decoys, minV, maxV);
    return (grid: g, bank: bank);
  }

  static List<BankNumber> _buildBank(
      List<int> answers, int decoys, int minV, int maxV) {
    final bank = <BankNumber>[
      ...answers.map(
              (v) => BankNumber(id: _rng.nextInt(1 << 31), value: v, used: false)),
    ];
    for (int i = 0; i < decoys; i++) {
      bank.add(
          BankNumber(id: _rng.nextInt(1 << 31), value: _rnd(minV, maxV), used: false));
    }
    bank.shuffle(_rng);
    return bank;
  }

  static int _rnd(int min, int max) => min + _rng.nextInt(max - min + 1);
}
