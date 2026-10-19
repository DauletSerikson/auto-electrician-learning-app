import 'package:electrician/main.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/widgets/lesson_blocks/question_block.dart';
import 'package:electrician/widgets/lesson_blocks/calculation_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';
import '../services/module_10_content_test.dart' show loadWiringRepair;

import 'package:electrician/theme/app_theme.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'remaining text and tasks fit 360 px at scale 1.3, dark=$dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1050));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final order in List.generate(10, (i) => i + 1)) {
          final lesson = (await tester.runAsync(
            () => loadWiringRepair(order),
          ))!;
          for (var index = 0; index < lesson.blocks.length; index++) {
            if (lesson.blocks[index] is ImageLessonBlock) continue;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(360, 1050),
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: LessonBlockRenderer(
                          key: ValueKey('$order-$index'),
                          block: lesson.blocks[index],
                          blockIndex: index,
                          onAnswered: (_) {},
                          onRetry: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'lesson $order, block $index',
            );
          }
        }
      },
    );
  }
  testWidgets('app discovers module 10 and opens its first real lesson', (
    tester,
  ) async {
    final preferences = PreferencesPlatformFake();
    preferences.values['flutter.completed_lessons'] = [
      'diagnostics_01',
      'diagnostics_10',
    ];
    preferences.install();
    addTearDown(preferences.uninstall);
    await tester.runAsync(() => CourseService().loadAllLessons());
    await tester.pumpWidget(const AutoElectricianApp());
    await settle(tester);
    await tap(tester, find.widgetWithText(ListTile, 'Курс'));
    final module = find.widgetWithText(
      ListTile,
      'Автомобильная проводка, разъёмы и ремонт электрических соединений',
    );
    if (module.evaluate().isEmpty) {
      await tester.scrollUntilVisible(module, 250);
    }
    await tap(tester, module);
    expect(find.byType(ModuleScreen), findsOneWidget);
    await tap(
      tester,
      find.widgetWithText(ListTile, 'Автомобильные провода и жгуты'),
    );
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(
      tester.widget<LessonScreen>(find.byType(LessonScreen)).lesson.id,
      'wiring_repair_01',
    );
    expect(preferences.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real module 10 mixed quiz retries, reaches 80% and explicitly saves',
    (tester) async {
      final preferences = PreferencesPlatformFake();
      preferences.values['flutter.completed_lessons'] = [
        'vehicle_07',
        'starting_charging_10',
      ];
      preferences.install();
      addTearDown(preferences.uninstall);
      await tester.binding.setSurfaceSize(const Size(800, 40000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final lesson = (await tester.runAsync(() => loadWiringRepair(10)))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonScreen(lesson: lesson),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Open'));
      expect(find.byType(QuestionBlock), findsNWidgets(13));
      expect(find.byType(CalculationBlock), findsNWidgets(2));
      final indices = [
        for (var i = 0; i < lesson.blocks.length; i++)
          if (lesson.blocks[i] is QuestionLessonBlock ||
              lesson.blocks[i] is CalculationLessonBlock)
            i,
      ];
      Finder card(int task) => find.byKey(
        ValueKey('${lesson.blocks[indices[task]].type}_${indices[task]}'),
      );
      Future<void> answer(int task, bool correct) async {
        final block = lesson.blocks[indices[task]];
        final target = card(task);
        if (block case QuestionLessonBlock(
          :final correctAnswer,
          :final answers,
        )) {
          await tap(
            tester,
            find
                .descendant(
                  of: target,
                  matching: find.byType(RadioListTile<int>),
                )
                .at(
                  correct
                      ? correctAnswer
                      : (correctAnswer + 1) % answers.length,
                ),
          );
        } else if (block case CalculationLessonBlock(:final correctValue)) {
          await tester.enterText(
            find.descendant(of: target, matching: find.byType(TextField)),
            '${correct ? correctValue : correctValue + 1}'.replaceAll('.', ','),
          );
        }
        await tap(
          tester,
          find.descendant(
            of: target,
            matching: find.widgetWithText(FilledButton, 'Проверить'),
          ),
        );
      }

      for (var task = 0; task < 15; task++) {
        await answer(task, task < 12 && task != 2);
      }
      final complete = find.widgetWithText(FilledButton, 'Завершить проверку');
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      expect(preferences.writes, 0);
      await tap(
        tester,
        find.descendant(
          of: card(2),
          matching: find.widgetWithText(OutlinedButton, 'Попробовать ещё раз'),
        ),
      );
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await answer(2, true);
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      expect(preferences.writes, 0);
      // Even at 80%, a retried unanswered question blocks explicit completion.
      await tap(
        tester,
        find.descendant(
          of: card(12),
          matching: find.widgetWithText(OutlinedButton, 'Попробовать ещё раз'),
        ),
      );
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await answer(12, false);
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      expect(preferences.writes, 0);
      await tap(tester, complete);
      expect(find.byType(LessonScreen), findsNothing);
      expect(preferences.values['flutter.completed_lessons'], [
        'vehicle_07',
        'starting_charging_10',
        'wiring_repair_10',
      ]);
      expect(preferences.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
