import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/classroom.dart';
import '../models/user.dart';
import 'package:uuid/uuid.dart';

class ClassroomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    await _firestore
        .collection('classrooms')
        .doc(classroom.id)
        .set(classroom.toJson());
    return classroom;
  }

  Future<void> requestToJoinClassroom({
    required String classroomCode,
    required String studentId,
  }) async {
    final query =
        await _firestore
            .collection('classrooms')
            .where('code', isEqualTo: classroomCode)
            .get();
    if (query.docs.isEmpty) throw Exception('Classroom not found');
    final doc = query.docs.first;
    final classroom = Classroom.fromJson(doc.data());
    if (classroom.studentIds.contains(studentId) ||
        classroom.pendingStudentIds.contains(studentId)) {
      throw Exception('Already requested or joined');
    }
    final updatedPending = List<String>.from(classroom.pendingStudentIds)
      ..add(studentId);
    await _firestore.collection('classrooms').doc(classroom.id).update({
      'pendingStudentIds': updatedPending,
    });
  }

  Future<void> acceptStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final doc =
        await _firestore.collection('classrooms').doc(classroomId).get();
    if (!doc.exists) throw Exception('Classroom not found');
    final classroom = Classroom.fromJson(doc.data() as Map<String, dynamic>);
    final updatedPending = List<String>.from(classroom.pendingStudentIds)
      ..remove(studentId);
    final updatedStudents = List<String>.from(classroom.studentIds);
    if (!updatedStudents.contains(studentId)) {
      updatedStudents.add(studentId);
    }
    await _firestore.collection('classrooms').doc(classroomId).update({
      'pendingStudentIds': updatedPending,
      'studentIds': updatedStudents,
      'updatedAt': DateTime.now(),
    });

    await _firestore.collection('users').doc(studentId).update({
      'classroomId': classroomId,
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> rejectStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final doc =
        await _firestore.collection('classrooms').doc(classroomId).get();
    if (!doc.exists) throw Exception('Classroom not found');
    final classroom = Classroom.fromJson(doc.data() as Map<String, dynamic>);
    final updatedPending = List<String>.from(classroom.pendingStudentIds)
      ..remove(studentId);
    await _firestore.collection('classrooms').doc(classroomId).update({
      'pendingStudentIds': updatedPending,
    });
  }

  Future<void> removeStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final doc =
        await _firestore.collection('classrooms').doc(classroomId).get();
    if (!doc.exists) throw Exception('Classroom not found');
    final classroom = Classroom.fromJson(doc.data() as Map<String, dynamic>);
    final updatedStudents = List<String>.from(classroom.studentIds)
      ..remove(studentId);
    await _firestore.collection('classrooms').doc(classroomId).update({
      'studentIds': updatedStudents,
    });

    await _firestore.collection('users').doc(studentId).update({
      'classroomId': null,
      'updatedAt': DateTime.now(),
    });
  }

  Future<Classroom?> getClassroomByCode(String code) async {
    final query =
        await _firestore
            .collection('classrooms')
            .where('code', isEqualTo: code)
            .get();
    if (query.docs.isEmpty) return null;
    return Classroom.fromJson(query.docs.first.data());
  }

  Future<Classroom?> getClassroomById(String id) async {
    final doc = await _firestore.collection('classrooms').doc(id).get();
    if (!doc.exists) return null;
    return Classroom.fromJson(doc.data() as Map<String, dynamic>);
  }

  Future<List<User>> getAcceptedStudents(String classroomId) async {
    final classroom = await getClassroomById(classroomId);
    if (classroom == null) return [];
    if (classroom.studentIds.isEmpty) return [];
    final query =
        await _firestore
            .collection('users')
            .where('id', whereIn: classroom.studentIds)
            .get();
    return query.docs.map((doc) => User.fromJson(doc.data())).toList();
  }

  Future<List<User>> getPendingStudents(String classroomId) async {
    final classroom = await getClassroomById(classroomId);
    if (classroom == null) return [];
    if (classroom.pendingStudentIds.isEmpty) return [];
    final query =
        await _firestore
            .collection('users')
            .where('id', whereIn: classroom.pendingStudentIds)
            .get();
    return query.docs.map((doc) => User.fromJson(doc.data())).toList();
  }

  Future<void> updateClassroom(Classroom classroom) async {
    await _firestore.collection('classrooms').doc(classroom.id).update({
      'name': classroom.name,
      'description': classroom.description,
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> deleteClassroom(String classroomId) async {
    await _firestore.collection('classrooms').doc(classroomId).delete();
  }
}
