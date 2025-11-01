import 'package:flutter/material.dart';
import 'package:pracpro/modules/basic_operators/addition/crossword_cell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BasicOperatorCrosswordBuilderScreen extends StatefulWidget {
  final String operator;
  final String gameId;
  final String difficulty;
  final Map<String, dynamic> config;
  final String title;
  final String description;

  const BasicOperatorCrosswordBuilderScreen({
    super.key,
    required this.operator,
    required this.gameId,
    required this.difficulty,
    required this.config,
    required this.title,
    required this.description,
  });

  @override
  State<BasicOperatorCrosswordBuilderScreen> createState() =>
      _BasicOperatorCrosswordBuilderScreenState();
}

class _BasicOperatorCrosswordBuilderScreenState
    extends State<BasicOperatorCrosswordBuilderScreen> {
  final _supabase = Supabase.instance.client;
  static const gridSize = 5;
  late List<List<CrosswordCell>> _grid;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _grid = List.generate(
      gridSize,
          (r) => List.generate(
        gridSize,
            (c) => CrosswordCell(row: r, col: c, type: CellType.empty),
      ),
    );
  }

  void _cycleCellType(CrosswordCell cell) async {
    final types = CellType.values;
    final idx = types.indexOf(cell.type);
    final next = types[(idx + 1) % types.length];

    String? newValue = cell.value;
    int? newAnswer = cell.answer;

    if (next == CellType.number || next == CellType.answer) {
      final v = await _askValue(cell.value);
      if (v == null) return;
      newValue = v;
      newAnswer = int.tryParse(v);
    } else if (next == CellType.operator) {
      final op = await _askOperator(cell.value);
      if (op == null) return;
      newValue = op;
    } else {
      newValue = '';
      newAnswer = null;
    }

    setState(() {
      cell
        ..type = next
        ..value = newValue
        ..isCorrect = false;
    });
  }

  Future<String?> _askValue(String? prev) async {
    final controller = TextEditingController(text: prev ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 12'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<String?> _askOperator(String? prev) async {
    const ops = ['+', '-', '×', '÷'];
    return showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Choose Operator'),
        children: [
          for (final o in ops)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, o),
              child: Center(
                child: Text(
                  o,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveToSupabase() async {
    final validationError = _validateCrossword();
    if (validationError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ $validationError')));
      return;
    }

    final jsonGrid =
    _grid.map((row) => row.map((c) => c.toJson()).toList()).toList();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ You must be logged in to save.')),
        );
        return;
      }

      await _supabase.from('crossword_puzzles').insert({
        'operator': widget.operator,
        'game_id': widget.gameId,
        'title': widget.title,
        'difficulty': widget.difficulty,
        'grid': jsonGrid,
        'bank': [],
        'created_by': user.id,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Crossword saved to Supabase!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Failed to save: $e')));
    }
  }

  String? _validateCrossword() {
    final allowedOperator = switch (widget.operator.toLowerCase()) {
      'addition' => '+',
      'subtraction' => '-',
      'multiplication' => '×',
      'division' => '÷',
      _ => null,
    };

    int numberCount = 0;
    int operatorCount = 0;

    for (final row in _grid) {
      for (final cell in row) {
        if (cell.type == CellType.number || cell.type == CellType.answer) {
          if (cell.value == null || cell.value!.isEmpty) {
            return 'Some number cells are empty.';
          }
          if (int.tryParse(cell.value!) == null) {
            return 'Invalid number: "${cell.value}"';
          }
          numberCount++;
        } else if (cell.type == CellType.operator) {
          if (cell.value == null || cell.value!.isEmpty) {
            return 'Some operator cells are empty.';
          }
          if (cell.value != allowedOperator) {
            return 'Invalid operator "${cell.value}". Only "$allowedOperator" is allowed for ${widget.operator}.';
          }
          operatorCount++;
        }
      }
    }

    if (numberCount < 2 || operatorCount == 0) {
      return 'Incomplete crossword: must have at least two numbers and one operator.';
    }

    return null;
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _legendItem(Colors.purple[100]!, 'Number'),
        _legendItem(Colors.blue[100]!, 'Operator'),
        _legendItem(Colors.orange[100]!, 'Equals (=)'),
        _legendItem(Colors.green[100]!, 'Answer (Correct)'),
        _legendItem(Colors.grey[200]!, 'Blank (Student fills)'),
        _legendItem(Colors.white, 'Empty'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text('Crossword Builder (${widget.operator} - ${widget.difficulty})'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.deepPurple.shade50,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (widget.description.isNotEmpty)
                      Text(widget.description,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text('Difficulty: ${widget.difficulty.toUpperCase()}',
                        style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🧩 Tap a cell to change its type. Long-press a cell to check its current type.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 16),
            _buildGrid(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Crossword to Supabase'),
              onPressed: _saveToSupabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int r = 0; r < gridSize; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int c = 0; c < gridSize; c++)
                GestureDetector(
                  onTap: () => _cycleCellType(_grid[r][c]),
                  onLongPress: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text(
                            'Cell type: ${_grid[r][c].type.name.toUpperCase()}'),
                      ),
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _colorForType(_grid[r][c].type),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Text(
                      _grid[r][c].value ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Color _colorForType(CellType type) {
    switch (type) {
      case CellType.number:
        return Colors.purple[100]!;
      case CellType.answer:
        return Colors.green[100]!;
      case CellType.operator:
        return Colors.blue[100]!;
      case CellType.equals:
        return Colors.orange[100]!;
      case CellType.blank:
        return Colors.grey[200]!;
      default:
        return Colors.white;
    }
  }
}
