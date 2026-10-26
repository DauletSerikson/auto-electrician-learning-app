import '../support/quiz_test_actions.dart' as quiz_actions;

import 'dart:async';

import 'package:electrician/main.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';
import '../services/module_9_content_test.dart' show loadStartingCharging;

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
            () => loadStartingCharging(order),
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
  testWidgets('app discovers module 9 and opens its first real lesson', (
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
      'Запуск, зарядка и паразитное потребление',
    );
    if (module.evaluate().isEmpty) {
      await tester.scrollUntilVisible(module, 250);
    }
    await tap(tester, module);
    expect(find.byType(ModuleScreen), findsOneWidget);
    await tap(
      tester,
      find.widgetWithText(ListTile, 'Устройство и характеристики АКБ'),
    );
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(
      tester.widget<LessonScreen>(find.byType(LessonScreen)).lesson.id,
      'starting_charging_01',
    );
    expect(preferences.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real module 9 quiz fails, retries, passes and explicitly saves',
    (tester) async {
      final preferences = PreferencesPlatformFake();
      preferences.values['flutter.completed_lessons'] = [
        'diagnostics_01',
        'diagnostics_10',
      ];
      preferences.install();
      addTearDown(preferences.uninstall);
      await tester.binding.setSurfaceSize(const Size(800, 45000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final lesson = await tester.runAsync(
        () =>
            CourseService().loadLesson('assets/course/stage_8/lesson_10.json'),
      );
      await tester.runAsync(() async {
        for (final asset
            in lesson!.blocks
                .whereType<ImageLessonBlock>()
                .map((b) => b.asset)
                .toSet()) {
          final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
          final ready = Completer<void>();
          final listener = ImageStreamListener(
            (_, _) => ready.complete(),
            onError: (Object e, StackTrace? s) => ready.completeError(e, s),
          );
          stream.addListener(listener);
          try {
            await ready.future.timeout(const Duration(seconds: 15));
          } finally {
            stream.removeListener(listener);
          }
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonScreen(lesson: lesson!),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Open'));
      final actualLesson = tester
          .widget<LessonScreen>(find.byType(LessonScreen))
          .lesson;
      expect(quiz_actions.quizTaskIndices(actualLesson), hasLength(15));
      expect(find.widgetWithText(FilledButton, 'Проверить'), findsNothing);
      expect(find.byKey(const ValueKey('quiz_submit')), findsOneWidget);
      final complete = find.widgetWithText(FilledButton, 'Завершить проверку');
      await quiz_actions.fillQuiz(
        tester,
        actualLesson,
        wrongTasks: {11, 12, 13, 14},
      );
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      expect(preferences.writes, 0);
      await quiz_actions.submitQuiz(tester);
      expect(find.text('73%'), findsOneWidget);
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      expect(preferences.writes, 0);
      await quiz_actions.retryQuiz(tester);
      expect(find.text('73%'), findsNothing);
      expect(find.text('Осталось без ответа: 15'), findsOneWidget);
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await quiz_actions.fillQuiz(
        tester,
        actualLesson,
        wrongTasks: {12, 13, 14},
      );
      // Drafts alone must never enable explicit completion or write progress.
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      expect(preferences.writes, 0);
      await quiz_actions.submitQuiz(tester);
      expect(find.text('80%'), findsOneWidget);
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      expect(preferences.writes, 0);
      await tap(tester, complete);
      expect(find.byType(LessonScreen), findsNothing);
      expect(preferences.values['flutter.completed_lessons'], [
        'diagnostics_01',
        'diagnostics_10',
        'starting_charging_10',
      ]);
      expect(preferences.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
