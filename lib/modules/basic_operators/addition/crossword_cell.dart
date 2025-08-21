enum CellType { number, operator, equals, blank, empty, answer }

class CrosswordCell {
  String? value; // User input (nullable)
  final CellType type; // Type of the cell
  int? answer; // Correct answer (used for blank/answer types)
  bool isDraggable; // For future drag-and-drop functionality
  bool isCorrect; // Indicates if the answer is correct (optional)

  CrosswordCell({
    this.value,
    required this.type,
    this.answer,
    this.isDraggable = false,
    this.isCorrect = false,
  });
}
