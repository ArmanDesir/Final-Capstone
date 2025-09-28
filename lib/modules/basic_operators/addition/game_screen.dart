import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crossword_math_game.dart';
import 'ninja_math_game.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({Key? key}) : super(key: key);

  Future<void> _saveGameProgress(
      String game,
      String difficulty,
      int score,
      int elapsedSeconds,
      ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final existing = await Supabase.instance.client
        .from('game_progress')
        .select()
        .eq('user_id', user.id)
        .eq('game_name', game)
        .eq('difficulty', difficulty);

    final attempts = existing.length;

    if (attempts >= 3) {
      return;
    }

    await Supabase.instance.client.from('game_progress').insert({
      'user_id': user.id,
      'game_name': game,
      'difficulty': difficulty,
      'score': score,
      'tries': attempts + 1,
      'status': 'complete',
      'elapsed_time': elapsedSeconds,
    });
  }

  void _startGame(BuildContext context, String game, String difficulty) async {
    Widget screen;
    if (game == 'Crossword Math') {
      screen = CrosswordMathGameScreen(difficulty: difficulty);
    } else {
      screen = NinjaMathGameScreen(difficulty: difficulty);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    if (result is Map<String, dynamic>) {
      final score = result['score'] as int? ?? 0;
      final elapsed = result['elapsed'] as int? ?? 0;
      await _saveGameProgress(game, difficulty, score, elapsed);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Addition Games'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _GameCard(
              title: 'Crossword Math',
              icon: Icons.grid_on,
              onSelect: (difficulty) =>
                  _startGame(context, 'Crossword Math', difficulty),
            ),
            const SizedBox(height: 24),
            _GameCard(
              title: 'Ninja Math',
              icon: Icons.sports_martial_arts,
              onSelect: (difficulty) =>
                  _startGame(context, 'Ninja Math', difficulty),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final void Function(String difficulty) onSelect;

  const _GameCard({
    required this.title,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.purple[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 36, color: Colors.purple),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Choose difficulty:'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DifficultyButton(label: 'Easy', onTap: () => onSelect('Easy')),
                _DifficultyButton(
                  label: 'Medium',
                  onTap: () => onSelect('Medium'),
                ),
                _DifficultyButton(label: 'Hard', onTap: () => onSelect('Hard')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DifficultyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}
