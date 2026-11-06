import 'package:flutter/material.dart';

import '../models/home_progress.dart';
import '../practice/practice_service.dart';
import '../services/course_service.dart';
import '../services/progress_service.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';
import 'practice_catalog_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CourseService courseService = CourseService();
  final ProgressService progressService = ProgressService();

  HomeProgress? progress;
  int moduleCount = 0;
  // Start with the subtitle's FutureBuilder, which also handles load errors.
  late final Future<int> practiceCaseCount = PracticeService()
      .loadCatalog()
      .then((definitions) => definitions.length);

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadProgress();
  }

  Future<void> loadProgress() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      progress = null;
    });
    try {
      final allLessons = await courseService.loadAllLessons();
      final result = await progressService.calculateProgress(allLessons);
      if (!mounted) return;
      setState(() {
        progress = result;
        moduleCount = allLessons.map((item) => item.module.id).toSet().length;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        progress = null;
      });
    }
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Не удалось загрузить прогресс'),
            TextButton(onPressed: loadProgress, child: const Text('Повторить')),
          ],
        ),
      );
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

        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Общий прогресс',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(data.progress * 100).round()}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ExcludeSemantics(
                      // The card already announces the percentage and lesson count.
                      child: LinearProgressIndicator(value: data.progress),
                    ),
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
        ),

        if (data.nextLesson != null || data.totalLessons > 0)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: data.nextLesson != null
                ? buildContinueCard(context, data)
                : const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('✓ Все доступные уроки завершены!'),
                    ),
                  ),
          ),

        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Курс'),
              subtitle: Text(
                'Учебных модулей: $moduleCount\nУроков: ${data.totalLessons}',
              ),
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
        ),
        Card(
          child: ListTile(
            key: const ValueKey('open_diagnostic_practice'),
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Практика диагноста'),
            subtitle: FutureBuilder<int>(
              future: practiceCaseCount,
              builder: (context, snapshot) => Text(
                snapshot.hasData
                    ? 'Диагностических кейсов: ${snapshot.data}\n'
                          'Проверки и доказательства'
                    : 'Проверки и доказательства',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PracticeCatalogScreen(),
              ),
            ),
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
