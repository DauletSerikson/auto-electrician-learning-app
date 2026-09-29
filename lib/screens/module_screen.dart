import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import '../models/course_module.dart';
import '../models/lesson_summary.dart';
import '../services/course_service.dart';
import 'lesson_screen.dart';

class ModuleScreen extends StatefulWidget {
  final CourseModule module;

  const ModuleScreen({super.key, required this.module});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  final CourseService courseService = CourseService();
  final ProgressService progressService = ProgressService();

  late Future<List<LessonSummary>> lessonsFuture;

  Set<String> completedLessons = {};

  @override
  void initState() {
    super.initState();

    lessonsFuture = courseService.loadLessons(widget.module.id);

    loadProgress();
  }

  Future<void> loadProgress() async {
    final completed = await progressService.getCompletedLessons();

    if (!mounted) return;

    setState(() {
      completedLessons = completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.module.title)),
      body: FutureBuilder<List<LessonSummary>>(
        future: lessonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки уроков:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final lessons = snapshot.data ?? [];

          if (lessons.isEmpty) {
            return const Center(child: Text('В этом модуле пока нет уроков.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final isCompleted = completedLessons.contains(lesson.id);

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),

                  leading: CircleAvatar(
                    child: isCompleted
                        ? const Icon(Icons.check)
                        : Text('${lesson.order}'),
                  ),

                  title: Text(
                    lesson.title,
                    style: TextStyle(
                      fontWeight: isCompleted
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      Text(lesson.description),

                      const SizedBox(height: 4),

                      Text(
                        '≈ ${lesson.estimatedMinutes} мин.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final lessonData = await courseService.loadLesson(
                      'assets/course/'
                      '${widget.module.id}/'
                      '${lesson.file}',
                    );

                    if (!context.mounted) return;

                    final completed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonScreen(lesson: lessonData),
                      ),
                    );

                    if (completed == true) {
                      await loadProgress();
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
