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
          .order('created_at', ascending: false);

      if (response == null) {
        _teacherClassrooms = [];
      } else if (response is List) {
        _teacherClassrooms = response
            .map((c) => Classroom.fromJson(Map<String, dynamic>.from(c)))
            .toList();
      } else {
        _teacherClassrooms = [];
      }

      notifyListeners();
    } catch (e, stack) {
      Logger().e(
        'Error loading teacher classrooms',
        error: e,
        stackTrace: stack,
      );
      _setError(e.toString());
      _teacherClassrooms = [];
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
          .contains('student_ids', [studentId]);

      _studentClassrooms =
          (response as List).map((c) => Classroom.fromJson(c)).toList();

      _currentClassroom =
      _studentClassrooms.isNotEmpty ? _studentClassrooms.first : null;

      notifyListeners();
    } catch (e) {
      Logger().e('Error loading student classrooms: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
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

  Future<int> getCompletedLessonsCount({
    required String studentId,
    required String classroomId,
  }) async {
    final lessons = await _supabase
        .from('lessons')
        .select('id')
        .eq('classroom_id', classroomId);

    int completedCount = 0;

    for (final lesson in lessons) {
      final quizzes = await _supabase
          .from('quizzes')
          .select('id')
          .eq('lesson_id', lesson['id']);

      for (final quiz in quizzes) {
        final progress = await _supabase
            .from('quiz_progress')
            .select('highest_score')
            .eq('quiz_id', quiz['id'])
            .eq('user_id', studentId)
            .single();

        if (progress != null && (progress['highest_score'] as int) > 0) {
          completedCount++;
          break;
        }
      }
    }

    return completedCount;
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
      final classroomIds = _teacherClassrooms.map((c) => c.id).toList();
      if (classroomIds.isEmpty) {
        return {"lessons": 0, "quizzes": 0};
      }

      final lessonsResponse = await _supabase
          .from('lessons')
          .select('id')
          .inFilter('classroom_id', classroomIds)
          .eq('is_active', true);

      final quizzesResponse = await _supabase
          .from('quizzes')
          .select('id')
          .inFilter('classroom_id', classroomIds);;

      final lessonsCount = (lessonsResponse as List).length;
      final quizzesCount = (quizzesResponse as List).length;

      return {"lessons": lessonsCount, "quizzes": quizzesCount};
    } catch (e, stack) {
      Logger().e(
        'Error counting lessons/quizzes for teacher',
        error: e,
        stackTrace: stack,
      );
      _setError(e.toString());
      return {"lessons": 0, "quizzes": 0};
    }
  }
}
