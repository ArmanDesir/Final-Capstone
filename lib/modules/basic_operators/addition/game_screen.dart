import 'package:flutter/material.dart';
import 'package:pracpro/services/operator_game_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crossword_math_game.dart';
import 'ninja_math_game.dart';

class GameScreen extends StatelessWidget {
  final String operatorKey;
  const GameScreen({Key? key, required this.operatorKey}) : super(key: key);

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
    if (attempts >= 3) return;

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

  Future<void> _startGame(
      BuildContext context,
      String gameName,
      String difficulty,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final svc = OperatorGameService();
      final games = await svc.getGamesForOperator(operatorKey);

      final gameKey = gameName == 'Crossword Math' ? 'crossmath' : 'ninjamath';

      final gameData = games.firstWhere(
            (g) => g.gameKey == gameKey,
        orElse: () => throw Exception('Game not found for operator "$operatorKey"'),
      );

      print('🎯 Game found: ${gameData.title}');
      print('🧩 Variants count: ${gameData.variants.length}');
      for (final v in gameData.variants) {
        print('→ ${v.difficulty} | ${v.config}');
      }
      final variant = gameData.variants.firstWhere(
            (v) => v.difficulty.toLowerCase() == difficulty.toLowerCase(),
        orElse: () => gameData.variants.first,
      );

      final config = variant.config;
      Widget screen;
      if (gameKey == 'crossmath') {
        screen = CrosswordMathGameScreen(
          operator: operatorKey,
          difficulty: difficulty,
          config: config,
        );
      } else {
        screen = NinjaMathGameScreen(
          operator: operatorKey,
          difficulty: difficulty,
          config: config,
        );
      }

      Navigator.pop(context);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );

      if (result is Map<String, dynamic>) {
        final score = result['score'] as int? ?? 0;
        final elapsed = result['elapsed'] as int? ?? 0;
        await _saveGameProgress(gameName, difficulty, score, elapsed);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to start game: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorTitle =
        '${operatorKey[0].toUpperCase()}${operatorKey.substring(1)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('$operatorTitle Games'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
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
      color: Colors.deepPurple[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 36, color: Colors.deepPurple),
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
                _DifficultyButton(label: 'Medium', onTap: () => onSelect('Medium')),
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
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}
