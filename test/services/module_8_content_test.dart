import 'dart:io';

import 'package:electrician/domain/course_progress.dart';
import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'obd_pilot_content_test.dart' show loadObdPilot, textOf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'ten modules and all 102 unique lessons have consecutive metadata',
    () async {
      final modules = await course.loadModules();
      expect(modules.map((m) => m.id), List.generate(11, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(11, (i) => i));
      expect(modules[7].title, 'Компьютерная диагностика автомобиля');
      final all = await course.loadAllLessons();
      expect(all, hasLength(102));
      expect(all.map((e) => e.lesson.id).toSet(), hasLength(102));
      expect(all.take(62).last.lesson.id, 'electronics_10');
      expect(
        all.skip(62).take(10).map((e) => e.lesson.id),
        List.generate(10, (i) => 'obd_${(i + 1).toString().padLeft(2, '0')}'),
      );
      final summaries = await course.loadLessons('stage_7');
      expect(summaries.map((e) => e.order), List.generate(10, (i) => i + 1));
      var blocks = 0;
      var tasks = 0;
      final images = <String>{};
      for (final summary in summaries) {
        final lesson = await loadObdPilot(summary.order);
        expect(lesson.id, summary.id);
        expect(lesson.moduleId, 'stage_7');
        expect(lesson.title, summary.title);
        expect(lesson.description, summary.description);
        expect(lesson.estimatedMinutes, summary.estimatedMinutes);
        expect(
          summary.file,
          'lesson_${summary.order.toString().padLeft(2, '0')}.json',
        );
        expect(lesson.completion.isQuiz, summary.order == 10);
        expect(lesson.completion.passingScore, summary.order == 10 ? 80 : null);
        blocks += lesson.blocks.length;
        tasks += lesson.blocks.where(isScoredLessonBlock).length;
        for (final block in lesson.blocks) {
          expect(
            block.type,
            isIn([
              'text',
              'image',
              'remember',
              'warning',
              'question',
              'calculation',
            ]),
          );
          if (block case ImageLessonBlock(:final asset)) {
            images.add(asset);
            expect(
              (await rootBundle.load(asset)).lengthInBytes,
              greaterThan(0),
            );
            expect(
              File(
                asset
                    .replaceFirst('/obd/', '/obd/source/')
                    .replaceFirst('.png', '.svg'),
              ).existsSync(),
              isTrue,
            );
          }
        }
      }
      expect(blocks, 145);
      expect(tasks, 55);
      expect(images, hasLength(14));
    },
  );

  test(
    'real quiz is 15 questions with 80 percent and explicit eligibility',
    () async {
      final quiz = await loadObdPilot(10);
      expect(quiz.blocks.whereType<QuestionLessonBlock>(), hasLength(15));
      final indices = [
        for (var i = 0; i < quiz.blocks.length; i++)
          if (isScoredLessonBlock(quiz.blocks[i])) i,
      ];
      expect(indices, hasLength(15));
      final answers = {
        for (var i = 0; i < indices.length; i++) indices[i]: i < 11,
      };
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
      answers[indices[11]] = true;
      final pass = evaluateLessonAttempt(quiz, answers);
      expect(pass.scorePercent, 80);
      expect(pass.canComplete, isTrue);
      answers.remove(indices.last);
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
    },
  );

  test(
    'all 62 old completions and unknown IDs survive the 102 lesson course',
    () async {
      final all = await course.loadAllLessons();
      final oldIds = all.take(62).map((e) => e.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...oldIds, 'unknown_saved_id'],
      });
      final service = ProgressService();
      final before = await service.calculateProgress(all);
      expect(before.totalLessons, 102);
      expect(before.completedLessons, 62);
      expect(before.progress, 62 / 102);
      expect(before.nextLesson?.lesson.id, 'obd_01');
      await service.completeLesson('obd_01');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final reloaded = ProgressService();
      expect(await reloaded.getCompletedLessons(), {
        ...oldIds,
        'unknown_saved_id',
        'obd_01',
      });
      final after = await reloaded.calculateProgress(all);
      expect(after.completedLessons, 63);
      expect(after.progress, 63 / 102);
      expect(after.nextLesson?.lesson.id, 'obd_02');
      expect(prefs.getKeys(), {'completed_lessons'});
      final full = calculateCourseProgress(
        all,
        all.map((e) => e.lesson.id).toSet(),
      );
      expect(full.completedLessons, 102);
      expect(full.progress, 1);
      expect(full.nextLesson, isNull);
    },
  );

  test(
    'DLC orientation and assignments agree with authored pin geometry',
    () async {
      final text = textOf(await loadObdPilot(2));
      for (final value in [
        'лицевую часть',
        'широкая сторона',
        '1…8',
        '9…16',
        '4 — chassis ground',
        '5 — signal ground',
        '6 — CAN-H',
        '14 — CAN-L',
        '16 — положительное питание',
        'не каждый автомобиль',
        'зеркальный',
      ]) {
        expect(text, contains(value));
      }
      final svg = File('assets/images/obd/source/dlc_front.svg')
          .readAsStringSync();
      for (var pin = 1; pin <= 16; pin++) {
        final match = RegExp(
          '<text x="([^"]+)" y="([^"]+)"[^>]+id="pin$pin">$pin</text>',
        ).allMatches(svg).single;
        final column = (pin - 1) % 8;
        expect(
          double.parse(match[1]!),
          pin <= 8 ? 38 + column * 34 : 46 + column * 32,
        );
        expect(double.parse(match[2]!), 210 + ((pin - 1) ~/ 8) * 54);
      }
      expect(svg, contains('16,170 304,170 286,300 34,300'));
      expect(svg, contains('6 — CAN-H, 14 — CAN-L'));
    },
  );

  test(
    'status teaching separates confirmation, permanent, MIL and readiness',
    () async {
      final text = textOf(await loadObdPilot(5));
      for (final value in [
        'Pending',
        'Confirmed/stored',
        'не означает, что проблема существует прямо сейчас',
        'clear и отключение АКБ её не удаляют',
        'собственная успешная проверка',
        'unsupported',
        'not ready',
        'по диагностическим данным OFF',
      ]) {
        expect(text, contains(value));
      }
      final choices = (await loadObdPilot(5)).blocks
          .whereType<QuestionLessonBlock>()
          .map((b) => b.answers[b.correctAnswer])
          .join('\n');
      expect(choices, contains('не придумывать универсальный drive cycle'));
    },
  );

  test('comparison C balances the reference and plots independently', () async {
    final text = textOf(await loadObdPilot(8));
    for (final value in [
      '11,30−0,10=11,20 V',
      '14,20−11,30=2,90 V',
      '11,200 V',
      'Синтетический',
      't=0…4 s',
    ]) {
      expect(text, contains(value));
    }
    final svg = File('assets/images/obd/source/compare_voltage.svg')
        .readAsStringSync();
    for (final entry in {
      'battery': 14.2,
      'ecuSupply': 11.3,
      'ecuGround': .1,
    }.entries) {
      final match = RegExp('<rect id="${entry.key}"[^>]+width="([^"]+)"')
          .firstMatch(svg)!;
      expect(double.parse(match[1]!) * 15 / 230, closeTo(entry.value, 1e-9));
    }
    expect(11.3 - .1, closeTo(11.2, 1e-9));
    expect(14.2 - 11.3, closeTo(2.9, 1e-9));
  });
}
