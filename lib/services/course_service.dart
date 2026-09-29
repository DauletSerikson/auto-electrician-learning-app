import 'dart:convert';
import '../models/course_lesson.dart';

import 'package:flutter/services.dart';

import '../models/course_module.dart';
import '../models/lesson.dart';
import '../models/lesson_summary.dart';

class CourseService {
  Future<List<CourseModule>> loadModules() async {
    final jsonString =
        await rootBundle.loadString('assets/course/modules.json');

    final List<dynamic> jsonData = jsonDecode(jsonString);

    final modules = jsonData
        .map((item) => CourseModule.fromJson(item))
        .toList();

    modules.sort((a, b) => a.order.compareTo(b.order));

    return modules;
  }

  Future<List<LessonSummary>> loadLessons(String moduleId) async {
    final jsonString = await rootBundle.loadString(
      'assets/course/$moduleId/lessons.json',
    );

    final List<dynamic> jsonData = jsonDecode(jsonString);

    final lessons = jsonData
        .map((item) => LessonSummary.fromJson(item))
        .toList();

    lessons.sort((a, b) => a.order.compareTo(b.order));

    return lessons;
  }

  Future<Lesson> loadLesson(String path) async {
    final jsonString = await rootBundle.loadString(path);

    final Map<String, dynamic> jsonData = jsonDecode(jsonString);

    return Lesson.fromJson(jsonData);
  }

  Future<List<CourseLesson>> loadAllLessons() async {
  final modules = await loadModules();

  final List<CourseLesson> allLessons = [];

  for (final module in modules) {
    final lessons = await loadLessons(module.id);

    for (final lesson in lessons) {
      allLessons.add(
        CourseLesson(
          module: module,
          lesson: lesson,
        ),
      );
    }
  }

  return allLessons;
}
}