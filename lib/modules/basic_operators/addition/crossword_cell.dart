enum CellType { number, operator, equals, blank, empty, answer }

class CrosswordCell {
  final int row;
  final int col;
  String? value;
  final CellType type;
  final int? answer;
  bool isCorrect;

  CrosswordCell({
    required this.row,
    required this.col,
    required this.type,
    this.value,
    this.answer,
    this.isCorrect = false,
  });
}

class BankNumber {
  final int id;
  final int value;
  bool used;

  BankNumber({required this.id, required this.value, this.used = false});
}
