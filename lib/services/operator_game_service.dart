import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/operator_game.dart';

class OperatorGameService {
  final SupabaseClient _sp = Supabase.instance.client;

  Future<List<OperatorGame>> getGamesForOperator(String operatorKey) async {
    final res = await _sp
        .from('operator_games')
        .select('''
    id,
    operator,
    game_key,
    title,
    description,
    is_active,
    operator_game_variants_game_id_fkey (
      id,
      difficulty,
      config
    )
  ''')
        .eq('operator', operatorKey)
        .eq('is_active', true)
        .order('title');

    print('🎯 Raw game data: $res');

    if (res is! List) return [];
    return res
        .whereType<Map<String, dynamic>>()
        .map((g) {
      final variants = g['operator_game_variants_game_id_fkey'] as List?;
      if (variants != null) {
        for (final v in variants) {
          if (v is Map && v['config'] is String) {
            if (v is Map && v['config'] is String) {
              try {
                v['config'] = jsonDecode(v['config']);
              } catch (_) {
                v['config'] = {};
              }
            }
          }
        }
      }
      return OperatorGame.fromJson(g);
    })
        .toList();
  }

  Future<String> createGame({
    required String operatorKey,
    required String gameKey,
    required String title,
    String? description,
    Map<String, Map<String, dynamic>> variantsByDifficulty = const {},
    String? createdBy,
  }) async {
    try {
      final insert = await _sp
          .from('operator_games')
          .insert({
        'operator': operatorKey,
        'game_key': gameKey,
        'title': title,
        'description': description,
        if (createdBy != null) 'created_by': createdBy,
      })
          .select('id')
          .single();
      final gameId = insert['id'] as String;
      if (variantsByDifficulty.isNotEmpty) {
        final rows = variantsByDifficulty.entries.map((e) {
          final diff = e.key.toLowerCase();
          return {
            'game_id': gameId,
            'difficulty': diff,
            'config': e.value,
          };
        }).toList();

        await _sp.from('operator_game_variants').insert(rows);
      }

      return gameId;
    } catch (e) {
      throw Exception('Failed to create game: $e');
    }
  }
}
