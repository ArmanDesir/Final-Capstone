import 'dart:math';
import 'crossword_cell.dart';

class CrosswordGridGenerator {
  static final _rng = Random();

  static const _cfg = {
    'easy':   {'min': 1, 'max': 10, 'bankDecoys': 5, 'timeSec': 180},
    'medium': {'min': 1, 'max': 20, 'bankDecoys': 6, 'timeSec': 240},
    'hard':   {'min': 1, 'max': 50, 'bankDecoys': 7, 'timeSec': 300},
  };

  static Map<String, int> timers(String difficulty) {
    final d = difficulty.toLowerCase();
    final c = _cfg[d] ?? _cfg['easy']!;
    return {'timeSec': c['timeSec'] as int};
  }

  /// Returns (grid, bank) where bank already contains all blank answers plus decoys.
  static ({List<List<CrosswordCell>> grid, List<BankNumber> bank})
  additionGrid(String difficulty) {
    final d = difficulty.toLowerCase();
    final cfg = _cfg[d] ?? _cfg['easy']!;
    final minV = cfg['min'] as int;
    final maxV = cfg['max'] as int;
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
    final s1 = a + b;
    final c1 = _rnd(minV, maxV);
    final d1 = _rnd(minV, maxV);
    final s2 = c1 + d1;
    final s3 = s1 + _rnd(0, 2);
    final s4 = max(0, s2 - _rnd(0, 2));
    final s5 = s3 + s4;

    CrosswordCell blank(int r, int c, int ans) =>
        CrosswordCell(row: r, col: c, type: CellType.blank, answer: ans);

    CrosswordCell op(int r, int c, String v) =>
        CrosswordCell(row: r, col: c, type: CellType.operator, value: v);

    CrosswordCell eq(int r, int c) =>
        CrosswordCell(row: r, col: c, type: CellType.equals, value: '=');

    CrosswordCell ans(int r, int c, int v) =>
        CrosswordCell(row: r, col: c, type: CellType.answer, value: '$v');

    CrosswordCell empty(int r, int c) =>
        CrosswordCell(row: r, col: c, type: CellType.empty, value: '');

    g[0] = [blank(0,0,a), op(0,1,'+'), blank(0,2,b), eq(0,3), ans(0,4,s1)];
    g[1] = [op(1,0,'+'), op(1,1,'+'), op(1,2,'+'), eq(1,3), op(1,4,'+')];
    g[2] = [blank(2,0,c1), op(2,1,'+'), blank(2,2,d1), eq(2,3), ans(2,4,s2)];
    g[3] = [eq(3,0), eq(3,1), empty(3,2), eq(3,3), eq(3,4)];
    g[4] = [ans(4,0,s3), blank(4,1,s3), ans(4,2,s4), eq(4,3), ans(4,4,s5)];
    final answers = <int>{a, b, c1, d1, s3}.toList();
    final bank = <BankNumber>[
      ...answers.map((v) => BankNumber(id: _rng.nextInt(1 << 31), value: v)),
    ];
    for (int i = 0; i < decoys; i++) {
      bank.add(BankNumber(id: _rng.nextInt(1 << 31), value: _rnd(minV, maxV)));
    }
    bank.shuffle(_rng);

    return (grid: g, bank: bank);
  }

  static int _rnd(int min, int max) => min + _rng.nextInt(max - min + 1);
}
