import 'dart:async';

import 'package:electrician/main.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/widgets/lesson_blocks/question_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';
import '../services/electronics_pilot_content_test.dart' show loadPilot;

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
        for (final order in [1, 2, 5, 7, 8, 9, 10]) {
          final lesson = (await tester.runAsync(() => loadPilot(order)))!;
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
  testWidgets('app discovers module 7 and opens its first real lesson', (
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
      'Автомобильная электроника и электронные системы управления',
    );
    if (module.evaluate().isEmpty) {
      await tester.scrollUntilVisible(module, 250);
    }
    await tap(tester, module);
    expect(find.byType(ModuleScreen), findsOneWidget);
    await tap(
      tester,
      find.widgetWithText(ListTile, 'Введение в автомобильную электронику'),
    );
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(
      tester.widget<LessonScreen>(find.byType(LessonScreen)).lesson.id,
      'electronics_01',
    );
    expect(preferences.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real module 7 quiz fails, retries, passes and explicitly saves',
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
            CourseService().loadLesson('assets/course/stage_6/lesson_10.json'),
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
      final questions = lesson!.blocks
          .whereType<QuestionLessonBlock>()
          .toList();
      for (var i = 0; i < questions.length; i++) {
        final card = find.byType(QuestionBlock).at(i);
        final choice = i < 11
            ? questions[i].correctAnswer
            : (questions[i].correctAnswer + 1) % questions[i].answers.length;
        await tap(
          tester,
          find
              .descendant(of: card, matching: find.byType(RadioListTile<int>))
              .at(choice),
        );
        await tap(
          tester,
          find.descendant(
            of: card,
            matching: find.widgetWithText(FilledButton, 'Проверить'),
          ),
        );
      }
      final complete = find.widgetWithText(FilledButton, 'Завершить проверку');
      await tester.ensureVisible(complete);
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      expect(preferences.writes, 0);
      final retryCard = find.byType(QuestionBlock).at(11);
      await tap(
        tester,
        find.descendant(
          of: retryCard,
          matching: find.widgetWithText(OutlinedButton, 'Попробовать ещё раз'),
        ),
      );
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await tap(
        tester,
        find
            .descendant(
              of: retryCard,
              matching: find.byType(RadioListTile<int>),
            )
            .at(questions[11].correctAnswer),
      );
      await tap(
        tester,
        find.descendant(
          of: retryCard,
          matching: find.widgetWithText(FilledButton, 'Проверить'),
        ),
      );
      await tester.ensureVisible(complete);
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      expect(preferences.writes, 0);
      await tap(tester, complete);
      expect(find.byType(LessonScreen), findsNothing);
      expect(preferences.values['flutter.completed_lessons'], [
        'diagnostics_01',
        'diagnostics_10',
        'electronics_10',
      ]);
      expect(preferences.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
