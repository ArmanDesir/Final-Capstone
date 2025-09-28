import 'package:offline_first_app/models/classroom.dart';
import 'package:offline_first_app/models/user.dart' as app_model;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ClassroomService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = Uuid();

  String generateClassroomCode() {
    return _uuid.v4().substring(0, 6).toUpperCase();
  }

  Future<Classroom> createClassroom({
    required String name,
    required String description,
    required String teacherId,
  }) async {
    final code = generateClassroomCode();
    final classroom = Classroom(
      id: _uuid.v4(),
      name: name,
      teacherId: teacherId,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      code: code,
    );
    await _supabase.from('classrooms').insert(classroom.toJson());
    return classroom;
  }

  Future<void> requestToJoinClassroom({required String classroomCode, required String studentId,}) async {
    final classroom = await _supabase
        .from('classrooms')
        .select()
        .eq('code', classroomCode)
        .maybeSingle();

    if (classroom == null) {
      throw Exception('Classroom not found');
    }

    final classroomId = classroom['id'] as String;

    final existing = await _supabase
        .from('user_classrooms')
        .select()
        .eq('user_id', studentId)
        .eq('classroom_id', classroomId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Already requested or joined');
    }

    await _supabase.from('user_classrooms').insert({
      'user_id': studentId,
      'classroom_id': classroomId,
      'status': 'pending',
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> acceptStudent({required String classroomId, required String studentId,}) async {
    final updated = await _supabase
        .from('user_classrooms')
        .update({
      'status': 'accepted',
      'joined_at': DateTime.now().toIso8601String(),
    })
        .eq('classroom_id', classroomId)
        .eq('user_id', studentId);

    if (updated.isEmpty) {
      throw Exception('Student not found in pending list');
    }
  }

  Future<void> rejectStudent({required String classroomId, required String studentId,}) async {
    await _supabase
        .from('user_classrooms')
        .delete()
        .eq('classroom_id', classroomId)
        .eq('user_id', studentId)
        .eq('status', 'pending');
  }

  Future<void> removeStudent({required String classroomId, required String studentId,}) async {
    await _supabase
        .from('user_classrooms')
        .delete()
        .eq('classroom_id', classroomId)
        .eq('user_id', studentId)
        .eq('status', 'accepted');
  }

  Future<Classroom?> getClassroomByCode(String code) async {
    final response = await _supabase
        .from('classrooms')
        .select()
        .eq('code', code)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return Classroom.fromJson(response);
  }

  Future<Classroom?> getClassroomById(String id) async {
    final response = await _supabase
        .from('classrooms')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Classroom.fromJson(response);
  }

  Future<List<app_model.User>> getAcceptedStudents(String classroomId) async {
    final response = await _supabase
        .from('user_classrooms')
        .select('users(*)')
        .eq('classroom_id', classroomId)
        .eq('status', 'accepted');

    return response
        .map<app_model.User>((data) => app_model.User.fromJson(data['users']))
        .toList();
  }

  Future<List<app_model.User>> getPendingStudents(String classroomId) async {
    final response = await _supabase
        .from('user_classrooms')
        .select('users(*)')
        .eq('classroom_id', classroomId)
        .eq('status', 'pending');

    return response
        .map<app_model.User>((data) => app_model.User.fromJson(data['users']))
        .toList();
  }

  Future<void> updateClassroom(Classroom classroom) async {
    await _supabase.from('classrooms').update({
      'name': classroom.name,
      'description': classroom.description,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', classroom.id);
  }

  Future<void> softDeleteClassroom(String classroomId) async {
    await _supabase.from('classrooms').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', classroomId);
  }

}
