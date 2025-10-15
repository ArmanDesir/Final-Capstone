import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/basic_operator_exercise_service.dart';

class BasicOperatorExerciseProvider with ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> get exercises => _exercises;

  Future<void> loadExercises(String operator) async {
    try {
      final data = await supabase
          .from('basic_operator_exercises')
          .select('*')
          .eq('operator', operator)
          .order('created_at', ascending: false);

      _exercises = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createExercise({
    required String operator,
    required String title,
    required String lessonId,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? storagePath,
  }) async {
    try {
      await supabase.from('basic_operator_exercises').insert({
        'operator': operator,
        'title': title,
        'lesson_id': lessonId,
        'description': description,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'storage_path': storagePath,
        'created_at': DateTime.now().toIso8601String(),
      });

      await loadExercises(operator);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createExerciseWithFile({
    required String operator,
    required String title,
    required String lessonId,
    required File file,
    String? description,
  }) async {
    try {
      final service = BasicOperatorExerciseService();
      await service.createExercise(
        operator: operator,
        title: title,
        description: description,
        file: file,
        lessonId: lessonId,
      );

      await loadExercises(operator);
      notifyListeners();
      if (kDebugMode) {
        print('✅ Exercise uploaded and inserted successfully for $operator');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating exercise with file: $e');
      }
      rethrow;
    }
  }
}
