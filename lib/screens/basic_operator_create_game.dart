import 'package:flutter/material.dart';
import 'package:offline_first_app/screens/basic_operator_crossword_builder_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/operator_game_service.dart';

class BasicOperatorCreateGamePage extends StatefulWidget {
  final String operatorKey;
  const BasicOperatorCreateGamePage({super.key, required this.operatorKey});

  @override
  State<BasicOperatorCreateGamePage> createState() =>
      _BasicOperatorCreateGamePageState();
}

class _BasicOperatorCreateGamePageState
    extends State<BasicOperatorCreateGamePage> {
  final _formKey = GlobalKey<FormState>();
  final _svc = OperatorGameService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isSaving = false;
  String _selectedGame = 'crossmath';
  String _selectedDifficulty = 'Easy';

  final Map<String, Map<String, dynamic>> _configs = {
    'Easy': {'timeSec': 180, 'min': 1, 'max': 10},
    'Medium': {'timeSec': 240, 'min': 1, 'max': 20},
    'Hard': {'timeSec': 300, 'min': 1, 'max': 50},
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ You must be logged in.')),
        );
        return;
      }

      final config = _configs[_selectedDifficulty]!;

      final gameId = await _svc.createGame(
        operatorKey: widget.operatorKey,
        gameKey: _selectedGame,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        variantsByDifficulty: {
          _selectedDifficulty.toLowerCase(): _configs[_selectedDifficulty]!,
        },
        createdBy: user.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Game created successfully (ID: $gameId)')),
      );
      if (_selectedGame == 'crossmath') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BasicOperatorCrosswordBuilderScreen(
              operator: widget.operatorKey,
              gameId: gameId,
              difficulty: _selectedDifficulty.toLowerCase(),
              config: config,
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Game'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Game Type'),
                value: _selectedGame,
                items: const [
                  DropdownMenuItem(
                      value: 'crossmath', child: Text('CrossMath')),
                  DropdownMenuItem(
                      value: 'ninjamath', child: Text('Ninja Math')),
                ],
                onChanged: (v) => setState(() => _selectedGame = v ?? 'crossmath'),
              ),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Game Title'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Title is required.' : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Difficulty'),
                value: _selectedDifficulty,
                items: const [
                  DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                ],
                onChanged: (v) =>
                    setState(() => _selectedDifficulty = v ?? 'Easy'),
              ),
              const SizedBox(height: 16),
              _buildConfigCard(_selectedDifficulty),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save & Continue'),
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🧩 Displays numeric config per difficulty
  Widget _buildConfigCard(String level) {
    final cfg = _configs[level]!;
    return Card(
      color: Colors.deepPurple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text('$level Settings'),
        initiallyExpanded: true,
        children: [
          _numField(cfg, 'timeSec', 'Time Limit (seconds)'),
          _numField(cfg, 'min', 'Minimum number'),
          _numField(cfg, 'max', 'Maximum number'),
        ],
      ),
    );
  }

  /// 🧩 Single numeric field
  Widget _numField(Map<String, dynamic> cfg, String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: cfg[key].toString(),
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        onChanged: (v) => cfg[key] = int.tryParse(v) ?? cfg[key],
      ),
    );
  }
}
