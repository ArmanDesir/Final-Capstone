import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/classroom.dart';
import '../models/user.dart' as app_model;

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

  Future<void> requestToJoinClassroom({
    required String classroomCode,
    required String studentId,
  }) async {
    final response = await _supabase
        .from('classrooms')
        .select()
        .eq('code', classroomCode)
        .single();

    if (response == null) {
      throw Exception('Classroom not found');
    }

    final classroom = Classroom.fromJson(response);
    if (classroom.studentIds.contains(studentId) ||
        classroom.pendingStudentIds.contains(studentId)) {
      throw Exception('Already requested or joined');
    }

    final updatedPending = List<String>.from(classroom.pendingStudentIds)
      ..add(studentId);

    await _supabase.from('classrooms').update({
      'pendingStudentIds': updatedPending,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', classroom.id);
  }

  Future<void> acceptStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final classroomResponse = await _supabase
        .from('classrooms')
        .select()
        .eq('id', classroomId)
        .single();

    if (classroomResponse == null) {
      throw Exception('Classroom not found');
    }

    final classroom = Classroom.fromJson(classroomResponse);
    final updatedPending = List<String>.from(classroom.pendingStudentIds)
      ..remove(studentId);
    final updatedStudents = List<String>.from(classroom.studentIds);
    if (!updatedStudents.contains(studentId)) {
      updatedStudents.add(studentId);
    }

    await _supabase.from('classrooms').update({
      'pendingStudentIds': updatedPending,
      'studentIds': updatedStudents,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', classroomId);

    await _supabase.from('users').update({
      'classroomId': classroomId,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', studentId);
  }

  Future<void> rejectStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final classroomResponse = await _supabase
        .from('classrooms')
        .select()
        .eq('id', classroomId)
        .single();

    if (classroomResponse == null) {
      throw Exception('Classroom not found');
    }

    final classroom = Classroom.fromJson(classroomResponse);
    final updatedPending = List<String>.from(classroom.pendingStudentIds)
      ..remove(studentId);

    await _supabase.from('classrooms').update({
      'pendingStudentIds': updatedPending,
    }).eq('id', classroomId);
  }

  Future<void> removeStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final classroomResponse = await _supabase
        .from('classrooms')
        .select()
        .eq('id', classroomId)
        .single();

    if (classroomResponse == null) {
      throw Exception('Classroom not found');
    }

    final classroom = Classroom.fromJson(classroomResponse);
    final updatedStudents = List<String>.from(classroom.studentIds)
      ..remove(studentId);

    await _supabase.from('classrooms').update({
      'studentIds': updatedStudents,
    }).eq('id', classroomId);

    await _supabase.from('users').update({
      'classroomId': null,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', studentId);
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
    final classroom = await getClassroomById(classroomId);
    if (classroom == null || classroom.studentIds.isEmpty) return [];

    final response = await _supabase
        .from('users')
        .select()
        .inFilter('id', classroom.studentIds);

    return response.map((data) => app_model.User.fromJson(data)).toList();
  }

  Future<List<app_model.User>> getPendingStudents(String classroomId) async {
    final classroom = await getClassroomById(classroomId);
    if (classroom == null || classroom.pendingStudentIds.isEmpty) return [];

    final response = await _supabase
        .from('users')
        .select()
        .inFilter('id', classroom.pendingStudentIds);

    return response.map((data) => app_model.User.fromJson(data)).toList();
  }

  Future<void> updateClassroom(Classroom classroom) async {
    await _supabase.from('classrooms').update({
      'name': classroom.name,
      'description': classroom.description,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', classroom.id);
  }

  Future<void> softDeleteClassroom(String classroomId) async {
    await _supabase.from('classrooms').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', classroomId);
  }

}
