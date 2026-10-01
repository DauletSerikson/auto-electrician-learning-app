import 'package:electrician/services/course_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CourseService courseService;

  setUp(() {
    courseService = CourseService();
  });

  group('CourseService — real course assets', () {
    test('loads all course modules', () async {
      final modules = await courseService.loadModules();

      expect(modules, isNotEmpty);

      expect(modules.length, 3);

      expect(
        modules.map((module) => module.id),
        containsAll(['stage_0', 'stage_1', 'stage_2']),
      );
    });

    test('modules are sorted by order', () async {
      final modules = await courseService.loadModules();

      for (var index = 1; index < modules.length; index++) {
        expect(
          modules[index].order,
          greaterThanOrEqualTo(modules[index - 1].order),
        );
      }
    });

    test('every module has a lesson index', () async {
      final modules = await courseService.loadModules();

      for (final module in modules) {
        final lessons = await courseService.loadLessons(module.id);

        expect(
          lessons,
          isNotEmpty,
          reason: '${module.id} должен содержать уроки',
        );
      }
    });

    test('lesson summaries are sorted by order', () async {
      final modules = await courseService.loadModules();

      for (final module in modules) {
        final lessons = await courseService.loadLessons(module.id);

        for (var index = 1; index < lessons.length; index++) {
          expect(
            lessons[index].order,
            greaterThanOrEqualTo(lessons[index - 1].order),
            reason:
                'Нарушен порядок уроков '
                'в ${module.id}',
          );
        }
      }
    });

    test('loads every lesson referenced by lessons.json', () async {
      final modules = await courseService.loadModules();

      for (final module in modules) {
        final summaries = await courseService.loadLessons(module.id);

        for (final summary in summaries) {
          final path =
              'assets/course/'
              '${module.id}/'
              '${summary.file}';

          final lesson = await courseService.loadLesson(path);

          expect(
            lesson.id,
            summary.id,
            reason:
                'ID в $path не совпадает '
                'с lessons.json',
          );

          expect(
            lesson.moduleId,
            module.id,
            reason:
                'moduleId урока '
                '${lesson.id} '
                'не совпадает с '
                '${module.id}',
          );

          expect(
            lesson.order,
            summary.order,
            reason:
                'Порядок урока '
                '${lesson.id} '
                'не совпадает с '
                'lessons.json',
          );

          expect(
            lesson.title,
            summary.title,
            reason:
                'Название урока '
                '${lesson.id} '
                'не совпадает с '
                'lessons.json',
          );
        }
      }
    });

    test('all module IDs are unique', () async {
      final modules = await courseService.loadModules();

      final ids = modules.map((module) => module.id).toList();

      expect(
        ids.toSet().length,
        ids.length,
        reason:
            'В modules.json есть '
            'повторяющиеся ID',
      );
    });

    test('all lesson IDs are globally unique', () async {
      final allLessons = await courseService.loadAllLessons();

      final ids = allLessons.map((item) => item.lesson.id).toList();

      expect(
        ids.toSet().length,
        ids.length,
        reason:
            'В курсе есть уроки '
            'с одинаковыми ID',
      );
    });

    test('every lesson has valid basic metadata', () async {
      final modules = await courseService.loadModules();

      for (final module in modules) {
        final summaries = await courseService.loadLessons(module.id);

        for (final summary in summaries) {
          final path =
              'assets/course/'
              '${module.id}/'
              '${summary.file}';

          final lesson = await courseService.loadLesson(path);

          expect(lesson.id.trim(), isNotEmpty, reason: '$path: пустой id');

          expect(
            lesson.title.trim(),
            isNotEmpty,
            reason: '$path: пустой title',
          );

          expect(
            lesson.description.trim(),
            isNotEmpty,
            reason: '$path: пустой description',
          );

          expect(
            lesson.estimatedMinutes,
            greaterThan(0),
            reason:
                '$path: estimatedMinutes '
                'должен быть больше 0',
          );

          expect(lesson.blocks, isNotEmpty, reason: '$path не содержит блоков');
        }
      }
    });

    test('quiz lessons have valid passing score', () async {
      final modules = await courseService.loadModules();

      for (final module in modules) {
        final summaries = await courseService.loadLessons(module.id);

        for (final summary in summaries) {
          final path =
              'assets/course/'
              '${module.id}/'
              '${summary.file}';

          final lesson = await courseService.loadLesson(path);

          if (!lesson.completion.isQuiz) {
            continue;
          }

          expect(
            lesson.completion.passingScore,
            isNotNull,
            reason:
                '${lesson.id}: '
                'quiz должен иметь '
                'passingScore',
          );

          expect(
            lesson.completion.passingScore,
            inInclusiveRange(1, 100),
            reason:
                '${lesson.id}: '
                'passingScore должен быть '
                'от 1 до 100',
          );
        }
      }
    });
  });
}
