import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/models/lesson_completion.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/quiz_test_actions.dart' as actions;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

Finder question(int index) => find.byKey(ValueKey('question_$index'));
Future<void> reveal(
  WidgetTester tester,
  Finder target,
  double direction,
) async {
  await actions.revealQuiz(tester, target, direction: direction, card: true);
}

int? selected(WidgetTester tester, int index) => tester
    .widget<RadioGroup<int>>(
      find.descendant(
        of: question(index),
        matching: find.byType(RadioGroup<int>),
      ),
    )
    .groupValue;

void main() {
  for (var stage = 0; stage < 14; stage++) {
    testWidgets(
      'real quiz stage_$stage retains drafts across scroll rebuild resize and grades once',
      (tester) async {
        final service = CourseService();
        final lesson = (await tester.runAsync(() async {
          final summaries = await service.loadLessons('stage_$stage');
          return service.loadLesson(
            'assets/course/stage_$stage/${summaries.last.file}',
          );
        }))!;
        expect(lesson.completion.isQuiz, isTrue);
        await tester.binding.setSurfaceSize(const Size(360, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Widget host() => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(stage.isEven ? 1.3 : 1)),
            child: child!,
          ),
          home: LessonScreen(key: const ValueKey('lesson'), lesson: lesson),
        );
        await tester.pumpWidget(host());
        await settle(tester);
        final ids = [
          for (var i = 0; i < lesson.blocks.length; i++)
            if (lesson.blocks[i] is QuestionLessonBlock) i,
        ];
        await reveal(tester, question(ids.first), 500);
        await actions.tapQuiz(
          tester,
          find
              .descendant(
                of: question(ids.first),
                matching: find.byType(RadioListTile<int>),
              )
              .first,
        );
        expect(selected(tester, ids.first), 0);
        await reveal(tester, question(ids.last), 500);
        await actions.tapQuiz(
          tester,
          find
              .descendant(
                of: question(ids.last),
                matching: find.byType(RadioListTile<int>),
              )
              .at(1),
        );
        for (var cycle = 0; cycle < 3; cycle++) {
          await reveal(tester, question(ids.first), -500);
          expect(selected(tester, ids.first), 0);
          await reveal(tester, question(ids.last), 500);
          expect(selected(tester, ids.last), 1);
        }
        await tester.binding.setSurfaceSize(const Size(600, 420));
        await tester.pumpWidget(host());
        await settle(tester);
        await reveal(tester, question(ids.first), -500);
        expect(selected(tester, ids.first), 0);
        await tester.binding.setSurfaceSize(const Size(360, 720));
        await settle(tester);
        await actions.fillQuiz(tester, lesson, wrongTasks: {});
        await actions.revealQuiz(
          tester,
          find.byKey(const ValueKey('quiz_submit')),
        );
        expect(find.text('Осталось без ответа: 0'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Проверить'), findsNothing);
        expect(
          find.widgetWithText(FilledButton, 'Проверить измерение'),
          findsNothing,
        );
        expect(
          find.widgetWithText(FilledButton, 'Проверить настройку'),
          findsNothing,
        );
        expect(
          find.widgetWithText(FilledButton, 'Проверить ответы'),
          findsOneWidget,
        );
        expect(find.text('✓ Проверка пройдена'), findsNothing);
        await actions.submitQuiz(tester);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('✓ Проверка пройдена'), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getStringList(
            'completed_lessons',
          ),
          isNull,
        );
        final complete = find.widgetWithText(
          FilledButton,
          'Завершить проверку',
        );
        expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
        final radios = find.descendant(
          of: find.byKey(
            ValueKey('question_${ids.first}'),
            skipOffstage: false,
          ),
          matching: find.byType(RadioListTile<int>, skipOffstage: false),
          skipOffstage: false,
        );
        expect(
          tester.widget<RadioListTile<int>>(radios.first).enabled,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final quiz in [true, false]) {
    testWidgets('draft selection survives real scroll disposal quiz=$quiz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Lesson lesson;
      if (quiz) {
        lesson = (await tester.runAsync(
          () => CourseService().loadLesson(
            'assets/course/stage_0/lesson_05.json',
          ),
        ))!;
      } else {
        lesson = Lesson(
          id: 'ordinary',
          moduleId: 'fixture',
          order: 1,
          title: 'Ordinary',
          description: '',
          estimatedMinutes: 1,
          completion: LessonCompletion(type: 'lesson'),
          blocks: List.generate(
            6,
            (i) => QuestionLessonBlock(
              question: 'Question $i',
              answers: const ['Yes', 'No'],
              correctAnswer: 0,
              explanation: 'Explanation $i',
            ),
          ),
        );
      }
      final ids = [
        for (var i = 0; i < lesson.blocks.length; i++)
          if (lesson.blocks[i] is QuestionLessonBlock) i,
      ];
      await tester.pumpWidget(MaterialApp(home: LessonScreen(lesson: lesson)));
      await settle(tester);
      await reveal(tester, question(ids.first), 300);
      await tester.tap(
        find
            .descendant(
              of: question(ids.first),
              matching: find.byType(RadioListTile<int>),
            )
            .first,
      );
      await settle(tester);
      expect(selected(tester, ids.first), 0);
      await reveal(tester, question(ids.last), 500);
      await tester.tap(
        find
            .descendant(
              of: question(ids.last),
              matching: find.byType(RadioListTile<int>),
            )
            .at(1),
      );
      await settle(tester);
      await reveal(tester, question(ids.first), -500);
      expect(
        selected(tester, ids.first),
        0,
        reason: 'first selection lost after visiting last question',
      );
      for (var cycle = 0; cycle < 2; cycle++) {
        await reveal(tester, question(ids.last), 500);
        expect(selected(tester, ids.last), 1);
        await reveal(tester, question(ids.first), -500);
        expect(selected(tester, ids.first), 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
