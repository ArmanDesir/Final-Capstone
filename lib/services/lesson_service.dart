import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lesson.dart';

class LessonService {
  final supabase = Supabase.instance.client;

  Future<List<Lesson>> getLessons(String classroomId) async {
    final response = await supabase
        .from('lessons')
        .select()
        .eq('classroom_id', classroomId);

    return (response as List)
        .map((data) => Lesson.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<Lesson> createLesson(Lesson lesson) async {
    final data = lesson.toJson();

    if (data['id'] == '' || data['id'] == null) {
      data.remove('id');
    }

    data.remove('created_at');
    data.remove('updated_at');

    final response = await supabase
        .from('lessons')
        .insert(data)
        .select()
        .single();

    return Lesson.fromJson(response as Map<String, dynamic>);
  }

  Future<void> updateLesson(Lesson lesson) async {
    final data = lesson.toJson();
    data['updated_at'] = DateTime.now().toIso8601String();

    await supabase
        .from('lessons')
        .update(data)
        .eq('id', lesson.id!);
  }

  Future<void> deleteLesson(String id) async {
    await supabase.from('lessons').delete().eq('id', id);
  }
}
