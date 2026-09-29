import 'package:flutter/material.dart';

import '../models/home_progress.dart';
import '../services/course_service.dart';
import '../services/progress_service.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CourseService courseService = CourseService();
  final ProgressService progressService = ProgressService();

  HomeProgress? progress;

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadProgress();
  }

  Future<void> loadProgress() async {
    final allLessons = await courseService.loadAllLessons();

    final result = await progressService.calculateProgress(allLessons);

    if (!mounted) return;

    setState(() {
      progress = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автоэлектрика с нуля')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : buildContent(context),
    );
  }

  Widget buildContent(BuildContext context) {
    final data = progress;

    if (data == null) {
      return const Center(child: Text('Не удалось загрузить прогресс'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.electric_bolt,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Автоэлектрика с нуля',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'От основ электричества '
                      'до диагностики автомобиля',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Общий прогресс',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    Text(
                      '${(data.progress * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: data.progress),
                ),

                const SizedBox(height: 10),

                Text(
                  '${data.completedLessons} '
                  'из ${data.totalLessons} уроков',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        if (data.nextLesson != null)
          buildContinueCard(context, data)
        else if (data.totalLessons > 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('✓ Все доступные уроки завершены!'),
            ),
          ),

        const SizedBox(height: 16),

        Card(
          child: ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Курс'),
            subtitle: const Text('Посмотреть все модули и уроки'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CourseScreen()),
              );

              await loadProgress();
            },
          ),
        ),
      ],
    );
  }

  Widget buildContinueCard(BuildContext context, HomeProgress data) {
    final item = data.nextLesson!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
          title: const Text('Продолжить обучение'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.lesson.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(item.module.title),

                const SizedBox(height: 4),

                Text('≈ ${item.lesson.estimatedMinutes} мин.'),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final lesson = await courseService.loadLesson(
              'assets/course/'
              '${item.module.id}/'
              '${item.lesson.file}',
            );

            if (!context.mounted) return;

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)),
            );

            await loadProgress();
          },
        ),
      ),
    );
  }
}
