import 'package:electrician/main.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/widgets/lesson_blocks/question_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets('app discovers module 4 and opens its first real lesson', (
    tester,
  ) async {
    final preferences = PreferencesPlatformFake()..install();
    addTearDown(preferences.uninstall);
    await tester.runAsync(() => CourseService().loadAllLessons());
    await tester.pumpWidget(const AutoElectricianApp());
    await settle(tester);
    await tap(tester, find.widgetWithText(ListTile, 'Курс'));
    final module = find.widgetWithText(
      ListTile,
      'Электрооборудование автомобиля',
    );
    if (module.evaluate().isEmpty) {
      await tester.scrollUntilVisible(module, 250);
    }
    await tap(tester, module);
    expect(find.byType(ModuleScreen), findsOneWidget);
    await tap(
      tester,
      find.widgetWithText(
        ListTile,
        'Общая электрическая архитектура автомобиля',
      ),
    );
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(
      tester.widget<LessonScreen>(find.byType(LessonScreen)).lesson.id,
      'vehicle_01',
    );
    expect(preferences.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real module 4 quiz fails, retries, passes and explicitly saves',
    (tester) async {
      final preferences = PreferencesPlatformFake()..install();
      addTearDown(preferences.uninstall);
      await tester.binding.setSurfaceSize(const Size(800, 18000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final lesson = await tester.runAsync(
        () =>
            CourseService().loadLesson('assets/course/stage_3/lesson_10.json'),
      );
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
      expect(preferences.values['flutter.completed_lessons'], ['vehicle_10']);
      expect(preferences.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
