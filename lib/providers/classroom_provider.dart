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

  // Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// ✅ Create Classroom
  Future<Classroom?> createClassroom({
    required String name,
    required String description,
  }) async {
    _setLoading(true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found");

      // 👇 Call the service (which already generates `code`)
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

  /// ✅ Load Teacher Classrooms
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
          .order('created_at', ascending: false) // newest first
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

  /// ✅ Load Student Classrooms
  Future<void> loadStudentClassrooms(String studentId) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('classrooms')
          .select()
          .contains('student_ids', [studentId]);

      _studentClassrooms =
          (response as List).map((c) => Classroom.fromJson(c)).toList();

      notifyListeners();
    } catch (e) {
      Logger().e('Error loading student classrooms: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ Load Classroom Details
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

  /// ✅ Accept Student
  Future<void> acceptStudent(String classroomId, String studentId) async {
    await _service.acceptStudent(
      classroomId: classroomId,
      studentId: studentId,
    );
    await loadClassroomDetails(classroomId);
    await loadTeacherClassrooms();
  }

  /// ✅ Reject Student
  Future<void> rejectStudent(String classroomId, String studentId) async {
    await _service.rejectStudent(
      classroomId: classroomId,
      studentId: studentId,
    );
    await loadClassroomDetails(classroomId);
  }

  /// ✅ Remove Student
  Future<void> removeStudent(String classroomId, String studentId) async {
    await _service.removeStudent(
      classroomId: classroomId,
      studentId: studentId,
    );
    await loadClassroomDetails(classroomId);
  }

  /// ✅ Request to Join
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

  /// ✅ Get Classroom by Code
  Future<Classroom?> getClassroomByCode(String code) async {
    return await _service.getClassroomByCode(code);
  }

  /// ✅ Get Classroom by Id
  Future<Classroom?> getClassroomById(String id) async {
    return await _service.getClassroomById(id);
  }

  /// ✅ Update Classroom
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

  /// ✅ Delete Classroom
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

  /// ✅ Get total lessons & quizzes for this teacher
  Future<Map<String, int>> getContentCountsForTeacher(String teacherId) async {
    try {
      // Lessons
      final lessonsResponse = await _supabase
          .from('content')
          .select('id')
          .eq('type', 'lesson')
          .inFilter('classroom_id', _teacherClassrooms.map((c) => c.id).toList());

      // Quizzes
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
