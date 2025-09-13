import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/classroom.dart';
import '../models/user.dart';
import '../services/classroom_service.dart';
import '../database/database_helper.dart';
import 'package:logger/logger.dart';

class ClassroomProvider with ChangeNotifier {
  final ClassroomService _service = ClassroomService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Classroom> _teacherClassrooms = [];
  List<Classroom> _studentClassrooms = [];
  Classroom? _currentClassroom;
  List<User> _acceptedStudents = [];
  List<User> _pendingStudents = [];
  bool _isLoading = false;
  String? _error;

  List<Classroom> get teacherClassrooms => _teacherClassrooms;
  List<Classroom> get studentClassrooms => _studentClassrooms;
  Classroom? get currentClassroom => _currentClassroom;
  List<User> get acceptedStudents => _acceptedStudents;
  List<User> get pendingStudents => _pendingStudents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// ✅ Allows switching classrooms manually from UI
  void setCurrentClassroom(Classroom? classroom) {
    _currentClassroom = classroom;
    notifyListeners();
  }

  Future<Classroom?> createClassroom({
    required String name,
    required String description,
  }) async {
    _setLoading(true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found");

      final classroom = await _service.createClassroom(
        name: name,
        description: description,
        teacherId: user.id,
      );

      await _databaseHelper.insertClassroom(classroom);
      _teacherClassrooms.add(classroom);

      notifyListeners();
      _setLoading(false);
      return classroom;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  Future<void> loadTeacherClassrooms() async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _setError("No logged in teacher found");
        _teacherClassrooms = [];
        return;
      }

      final response = await _supabase
          .from('classrooms')
          .select()
          .eq('teacher_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(3);

      _teacherClassrooms =
          (response as List).map((c) => Classroom.fromJson(c)).toList();

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadStudentClassrooms(String studentId) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('classrooms')
          .select()
          .contains('student_ids', [studentId]);  // still correct for your schema

      _studentClassrooms =
          (response as List).map((c) => Classroom.fromJson(c)).toList();

      _currentClassroom =
      _studentClassrooms.isNotEmpty ? _studentClassrooms.first : null;

      notifyListeners();
    } catch (e) {
      Logger().e('Error loading student classrooms: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false); // ✅ guaranteed reset
    }
  }

  Future<void> loadClassroomDetails(String classroomId) async {
    _setLoading(true);
    try {
      final classroom = await _service.getClassroomById(classroomId);
      _currentClassroom = classroom;

      if (classroom != null) {
        await _databaseHelper.insertClassroom(classroom);
        _acceptedStudents = await _service.getAcceptedStudents(classroomId);
        _pendingStudents = await _service.getPendingStudents(classroomId);
      }

      notifyListeners();
    } catch (e) {
      Logger().e('Error loading classroom details: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> acceptStudent(String classroomId, String studentId) async {
    await _service.acceptStudent(
      classroomId: classroomId,
      studentId: studentId,
    );
    await loadClassroomDetails(classroomId);
    await loadTeacherClassrooms();
  }

  Future<void> rejectStudent(String classroomId, String studentId) async {
    await _service.rejectStudent(
      classroomId: classroomId,
      studentId: studentId,
    );
    await loadClassroomDetails(classroomId);
  }

  Future<void> removeStudent(String classroomId, String studentId) async {
    await _service.removeStudent(
      classroomId: classroomId,
      studentId: studentId,
    );
    await loadClassroomDetails(classroomId);
  }

  Future<List<User>> getAcceptedStudentsForAllClassrooms() async {
    List<User> allStudents = [];

    for (var classroom in _teacherClassrooms) {
      final students = await _service.getAcceptedStudents(classroom.id);
      allStudents.addAll(students);
    }
    allStudents.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });
    return allStudents.take(3).toList();
  }

  Future<bool> requestToJoinClassroom({
    required String code,
    required String studentId,
  }) async {
    _setLoading(true);
    try {
      await _service.requestToJoinClassroom(
        classroomCode: code,
        studentId: studentId,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<Classroom?> getClassroomByCode(String code) async {
    return await _service.getClassroomByCode(code);
  }

  Future<Classroom?> getClassroomById(String id) async {
    return await _service.getClassroomById(id);
  }

  Future<void> updateClassroom(Classroom classroom) async {
    _setLoading(true);
    try {
      await _service.updateClassroom(classroom);
      await _databaseHelper.updateClassroom(classroom);
      await loadTeacherClassrooms();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteClassroom(String id) async {
    _setLoading(true);
    try {
      await _service.softDeleteClassroom(id);
      _teacherClassrooms.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, int>> getContentCountsForTeacher(String teacherId) async {
    try {
      final lessonsResponse = await _supabase
          .from('content')
          .select('id')
          .eq('type', 'lesson')
          .inFilter('classroom_id', _teacherClassrooms.map((c) => c.id).toList());

      final quizzesResponse = await _supabase
          .from('content')
          .select('id')
          .eq('type', 'quiz')
          .inFilter('classroom_id', _teacherClassrooms.map((c) => c.id).toList());

      return {
        "lessons": (lessonsResponse as List).length,
        "quizzes": (quizzesResponse as List).length,
      };
    } catch (e) {
      _setError(e.toString());
      return {"lessons": 0, "quizzes": 0};
    }
  }
}
