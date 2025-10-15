import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/basic_operator_lesson.dart';

class BasicOperatorLessonService {
  final _sb = Supabase.instance.client;
  final String bucket = 'basic-operator';

  Future<List<BasicOperatorLesson>> getLessons(String operator) async {
    final rows = await _sb
        .from('basic_operator_lessons')
        .select('*')
        .eq('operator', operator)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BasicOperatorLesson.fromJson)
        .toList();
  }

  Future<BasicOperatorLesson> createLesson(BasicOperatorLesson lesson) async {
    final data = lesson.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');

    final inserted = await _sb
        .from('basic_operator_lessons')
        .insert(data)
        .select('*')
        .single();

    return BasicOperatorLesson.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<BasicOperatorLesson> createLessonWithFile(
      BasicOperatorLesson lesson,
      File file,
      ) async {
    final fileExt = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${lesson.operator}/lessons/$timestamp.$fileExt';

    try {
      await _sb.storage.from(bucket).upload(path, file);
      final fileUrl = _sb.storage.from(bucket).getPublicUrl(path);
      print('📤 File uploaded to storage');
      print('→ Path: $path');
      print('→ Public URL: $fileUrl');
      final newLesson = lesson.copyWith(
        fileUrl: fileUrl,
        storagePath: path,
        fileName: file.path.split('/').last,
      );

      final data = newLesson.toJson()
        ..remove('id')
        ..remove('created_at')
        ..remove('updated_at');
      final inserted = await _sb
          .from('basic_operator_lessons')
          .insert(data)
          .select()
          .single();

      print('✅ Lesson inserted into DB for operator ${lesson.operator}');

      return BasicOperatorLesson.fromJson(Map<String, dynamic>.from(inserted));
    } catch (e) {
      print('❌ Error uploading file or inserting lesson: $e');
      rethrow;
    }
  }
}
