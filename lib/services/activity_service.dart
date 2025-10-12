import 'package:offline_first_app/models/activity_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ActivityProgress>> getActivityProgress(String classroomId) async {
    final res = await _supabase
        .from('activity_progress_by_classroom')
        .select('''
          source,source_id,user_id,user_name,
          entity_type,entity_id,entity_title,stage,
          score,attempt,highest_score,tries,status,
          classroom_id,created_at
        ''')
        .eq('classroom_id', classroomId)
        .order('created_at', ascending: false);

    if (res is! List) return [];
    return res
        .cast<Map<String, dynamic>>()
        .map(ActivityProgress.fromJson)
        .toList();
  }
}
