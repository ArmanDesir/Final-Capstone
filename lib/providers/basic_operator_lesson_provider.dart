import 'dart:io';
import 'package:flutter/material.dart';
import 'package:offline_first_app/models/basic_operator_lesson.dart';
import 'package:offline_first_app/services/basic_operator_lesson_service.dart';

class BasicOperatorLessonProvider with ChangeNotifier {
  final _service = BasicOperatorLessonService();

  List<BasicOperatorLesson> lessons = [];
  bool isLoading = false;
  String? error;

  Future<List<BasicOperatorLesson>> loadLessons(String operator) async {
    isLoading = true;
    notifyListeners();

    try {
      lessons = await _service.getLessons(operator);
      error = null;
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
    return lessons;
  }

  Future<void> createLesson(BasicOperatorLesson lesson) async {
    try {
      final created = await _service.createLesson(lesson);
      lessons.add(created);
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> createLessonWithFile(
      BasicOperatorLesson lesson, File file) async {
    try {
      final created = await _service.createLessonWithFile(lesson, file);
      lessons.add(created);
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
