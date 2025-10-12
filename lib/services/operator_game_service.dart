import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/operator_game.dart';

class OperatorGameService {
  final SupabaseClient _sp = Supabase.instance.client;

  Future<List<OperatorGame>> getGamesForOperator(String operatorKey) async {
    final res = await _sp
        .from('operator_games')
        .select('id, operator, game_key, title, description, is_active, '
        'variants:operator_game_variants (id, difficulty, config)')
        .eq('operator', operatorKey)
        .eq('is_active', true)
        .order('title');
    if (res is! List) return [];
    return res.cast<Map<String, dynamic>>().map(OperatorGame.fromJson).toList();
  }

  Future<String> createGame({
    required String operatorKey,
    required String gameKey,
    required String title,
    String? description,
    Map<String, Map<String, dynamic>> variantsByDifficulty = const {},
  }) async {
    final insert = await _sp.from('operator_games').insert({
      'operator': operatorKey,
      'game_key': gameKey,
      'title': title,
      'description': description,
    }).select('id').single();
    final gameId = insert['id'] as String;

    if (variantsByDifficulty.isNotEmpty) {
      final rows = variantsByDifficulty.entries.map((e) => {
        'game_id': gameId,
        'difficulty': e.key,
        'config': e.value,
      }).toList();
      await _sp.from('operator_game_variants').insert(rows);
    }
    return gameId;
  }
}
