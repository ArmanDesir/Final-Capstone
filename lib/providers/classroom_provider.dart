import 'package:flutter/material.dart';
import '../models/classroom.dart';
import '../models/user.dart';
import '../services/classroom_service.dart';
import '../database/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class ClassroomProvider with ChangeNotifier {
  final ClassroomService _service = ClassroomService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Classroom> _teacherClassrooms = [];
  Classroom? _currentClassroom;
  List<User> _acceptedStudents = [];
  List<User> _pendingStudents = [];
  bool _isLoading = false;
  String? _error;

  List<Classroom> get teacherClassrooms => _teacherClassrooms;
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

  Future<Classroom?> createClassroom({
    required String name,
    required String description,
    required String teacherId,
  }) async {
    _setLoading(true);
    try {
      final classroom = await _service.createClassroom(
        name: name,
        description: description,
        teacherId: teacherId,
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

  Future<void> loadTeacherClassrooms(String teacherId) async {
    _setLoading(true);
    try {
      List<Classroom> localClassrooms = await _databaseHelper
          .getClassroomsByTeacherId(teacherId);

      if (localClassrooms.isNotEmpty) {
        _teacherClassrooms = localClassrooms;
        notifyListeners();
      }

      try {
        final query =
            await FirebaseFirestore.instance
                .collection('classrooms')
                .where('teacherId', isEqualTo: teacherId)
                .get();
        List<Classroom> firebaseClassrooms =
            query.docs.map((doc) => Classroom.fromJson(doc.data())).toList();

        for (Classroom classroom in firebaseClassrooms) {
          await _databaseHelper.insertClassroom(classroom);
        }

        _teacherClassrooms = firebaseClassrooms;
        notifyListeners();
      } catch (e) {
        Logger().e('Error loading from Firebase: $e');
      }

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> loadStudentClassroom(String studentId) async {
    _setLoading(true);
    try {
      List<Classroom> localClassrooms = await _databaseHelper
          .getClassroomsByUserId(studentId);

      if (localClassrooms.isNotEmpty) {
        for (Classroom classroom in localClassrooms) {
          if (classroom.studentIds.contains(studentId)) {
            _currentClassroom = classroom;
            break;
          }
        }
        notifyListeners();
      }

      try {
        final query =
            await FirebaseFirestore.instance
                .collection('classrooms')
                .where('studentIds', arrayContains: studentId)
                .get();

        if (query.docs.isNotEmpty) {
          Classroom firebaseClassroom = Classroom.fromJson(
            query.docs.first.data(),
          );
          await _databaseHelper.insertClassroom(firebaseClassroom);
          _currentClassroom = firebaseClassroom;
        }

        notifyListeners();
      } catch (e) {
        Logger().e('Error loading from Firebase: $e');
      }

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> loadClassroomDetails(String classroomId) async {
    _setLoading(true);
    try {
      _currentClassroom = await _databaseHelper.getClassroomById(classroomId);

      if (_currentClassroom != null) {
        await _loadStudentsFromLocal(classroomId);
      }

      try {
        _currentClassroom = await _service.getClassroomById(classroomId);
        _acceptedStudents = await _service.getAcceptedStudents(classroomId);
        _pendingStudents = await _service.getPendingStudents(classroomId);

        if (_currentClassroom != null) {
          await _databaseHelper.insertClassroom(_currentClassroom!);
        }
      } catch (e) {
        Logger().e('Error loading from Firebase: $e');
      }

      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> _loadStudentsFromLocal(String classroomId) async {
    if (_currentClassroom != null) {
      _acceptedStudents = [];
      for (String studentId in _currentClassroom!.studentIds) {
        User? user = await _databaseHelper.getUserById(studentId);
        if (user != null) {
          _acceptedStudents.add(user);
        }
      }

      _pendingStudents = [];
      for (String studentId in _currentClassroom!.pendingStudentIds) {
        User? user = await _databaseHelper.getUserById(studentId);
        if (user != null) {
          _pendingStudents.add(user);
        }
      }
    }
  }

  Future<void> acceptStudent(String classroomId, String studentId) async {
    await _service.acceptStudent(
      classroomId: classroomId,
      studentId: studentId,
    );

    if (_currentClassroom != null) {
      List<String> updatedPending = List.from(
        _currentClassroom!.pendingStudentIds,
      )..remove(studentId);
      List<String> updatedStudents = List.from(_currentClassroom!.studentIds)
        ..add(studentId);

      Classroom updatedClassroom = _currentClassroom!.copyWith(
        pendingStudentIds: updatedPending,
        studentIds: updatedStudents,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateClassroom(updatedClassroom);
      _currentClassroom = updatedClassroom;
    }

    User? user = await _databaseHelper.getUserById(studentId);
    if (user != null) {
      User updatedUser = user.copyWith(
        classroomId: classroomId,
        updatedAt: DateTime.now(),
      );
      await _databaseHelper.updateUser(updatedUser);
    }

    await loadClassroomDetails(classroomId);
    if (_currentClassroom != null) {
      await loadTeacherClassrooms(_currentClassroom!.teacherId);
    }
    notifyListeners();
  }

  Future<void> rejectStudent(String classroomId, String studentId) async {
    await _service.rejectStudent(
      classroomId: classroomId,
      studentId: studentId,
    );

    if (_currentClassroom != null) {
      List<String> updatedPending = List.from(
        _currentClassroom!.pendingStudentIds,
      )..remove(studentId);

      Classroom updatedClassroom = _currentClassroom!.copyWith(
        pendingStudentIds: updatedPending,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateClassroom(updatedClassroom);
      _currentClassroom = updatedClassroom;
    }

    await loadClassroomDetails(classroomId);
    notifyListeners();
  }

  Future<void> removeStudent(String classroomId, String studentId) async {
    await _service.removeStudent(
      classroomId: classroomId,
      studentId: studentId,
    );

    if (_currentClassroom != null) {
      List<String> updatedStudents = List.from(_currentClassroom!.studentIds)
        ..remove(studentId);

      Classroom updatedClassroom = _currentClassroom!.copyWith(
        studentIds: updatedStudents,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateClassroom(updatedClassroom);
      _currentClassroom = updatedClassroom;
    }

    User? user = await _databaseHelper.getUserById(studentId);
    if (user != null) {
      User updatedUser = user.copyWith(
        classroomId: null,
        updatedAt: DateTime.now(),
      );
      await _databaseHelper.updateUser(updatedUser);
    }

    await loadClassroomDetails(classroomId);
    notifyListeners();
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

      Classroom? classroom = await _databaseHelper.getClassroomByCode(code);
      if (classroom != null) {
        List<String> updatedPending = List.from(classroom.pendingStudentIds)
          ..add(studentId);
        Classroom updatedClassroom = classroom.copyWith(
          pendingStudentIds: updatedPending,
          updatedAt: DateTime.now(),
        );
        await _databaseHelper.updateClassroom(updatedClassroom);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<Classroom?> getClassroomByCode(String code) async {
    Classroom? localClassroom = await _databaseHelper.getClassroomByCode(code);
    if (localClassroom != null) {
      return localClassroom;
    }

    return await _service.getClassroomByCode(code);
  }

  Future<Classroom?> getClassroomById(String id) async {
    Classroom? localClassroom = await _databaseHelper.getClassroomById(id);
    if (localClassroom != null) {
      return localClassroom;
    }

    return await _service.getClassroomById(id);
  }

  Future<void> updateClassroom(Classroom classroom) async {
    _setLoading(true);
    try {
      await _service.updateClassroom(classroom);
      await _databaseHelper.updateClassroom(classroom);
      await loadTeacherClassrooms(classroom.teacherId);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> deleteClassroom(String classroomId) async {
    _setLoading(true);
    try {
      await _service.deleteClassroom(classroomId);
      await _databaseHelper.deleteClassroom(classroomId);
      _teacherClassrooms.removeWhere((c) => c.id == classroomId);
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
}
