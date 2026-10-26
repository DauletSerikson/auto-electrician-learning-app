import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/models/lesson_completion.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/quiz_test_actions.dart' as actions;

Lesson fixture({bool quiz = true}) => Lesson(
  id: 'attempt',
  moduleId: 'fixture',
  order: 1,
  title: 'Attempt',
  description: '',
  estimatedMinutes: 1,
  completion: LessonCompletion(
    type: quiz ? 'quiz' : 'lesson',
    passingScore: quiz ? 60 : null,
  ),
  blocks: const [
    QuestionLessonBlock(
      question: 'First',
      answers: ['Yes', 'No'],
      correctAnswer: 0,
      explanation: 'First feedback',
    ),
    QuestionLessonBlock(
      question: 'Second',
      answers: ['Yes', 'No'],
      correctAnswer: 0,
      explanation: 'Second feedback',
    ),
    CalculationLessonBlock(
      question: 'Calculate',
      correctValue: 1.5,
      tolerance: 0.01,
      unit: 'V',
      hint: 'Hint',
      explanation: 'Calculation feedback',
    ),
  ],
);

Future<void> show(WidgetTester tester, Lesson lesson) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: LessonScreen(lesson: lesson)));
  await actions.settleQuiz(tester);
}

Finder get submit => find.byKey(const ValueKey('quiz_submit'));
Finder option(int question, int answer) => find
    .descendant(
      of: find.byKey(ValueKey('question_$question')),
      matching: find.byType(RadioListTile<int>),
    )
    .at(answer);
bool enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(submit).onPressed != null;

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'completed_lessons': ['previous', 'attempt'],
    }),
  );

  testWidgets(
    'missing answers, editable drafts, decimal input, freeze and whole retry',
    (tester) async {
      await show(tester, fixture());
      expect(find.text('Осталось без ответа: 3'), findsOneWidget);
      expect(enabled(tester), isFalse);
      await tester.tap(option(0, 1));
      await tester.pump();
      await tester.tap(option(0, 0));
      await tester.pump();
      await tester.tap(option(1, 1));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '.');
      await tester.pump();
      expect(find.text('Осталось без ответа: 1'), findsOneWidget);
      expect(enabled(tester), isFalse);
      await tester.enterText(find.byType(TextField), '1,5');
      await tester.pump();
      expect(enabled(tester), isTrue);
      expect(find.text('Проверить'), findsNothing);
      expect(submit, findsOneWidget);
      expect(find.text('✓ Проверка пройдена'), findsNothing);
      await tester.tap(submit);
      await actions.settleQuiz(tester);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('✓ Проверка пройдена'), findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(tester.widget<RadioListTile<int>>(option(0, 0)).enabled, isFalse);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(await ProgressService().getCompletedLessons(), {
        'previous',
        'attempt',
      });
      await tester.tap(find.byKey(const ValueKey('quiz_retry')));
      await actions.settleQuiz(tester);
      expect(find.text('✓ Проверка пройдена'), findsNothing);
      expect(find.text('Осталось без ответа: 3'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      final group = find.descendant(
        of: find.byKey(const ValueKey('question_0')),
        matching: find.byType(RadioGroup<int>),
      );
      expect(tester.widget<RadioGroup<int>>(group).groupValue, isNull);
      expect(await ProgressService().getCompletedLessons(), {
        'previous',
        'attempt',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopening an uncompleted quiz never restores a false PASS', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'completed_lessons': ['previous'],
    });
    final lesson = fixture();
    await show(tester, lesson);
    await actions.fillQuiz(tester, lesson, wrongTasks: {});
    await actions.submitQuiz(tester);
    expect(find.text('✓ Проверка пройдена'), findsOneWidget);
    expect(await ProgressService().getCompletedLessons(), {'previous'});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: LessonScreen(lesson: lesson)));
    await actions.settleQuiz(tester);
    expect(find.text('✓ Проверка пройдена'), findsNothing);
    expect(find.text('Осталось без ответа: 3'), findsOneWidget);
    expect(enabled(tester), isFalse);
    expect(await ProgressService().getCompletedLessons(), {'previous'});
  });

  testWidgets(
    'ordinary question checking and retry leave neighboring draft intact',
    (tester) async {
      await show(tester, fixture(quiz: false));
      await tester.tap(option(0, 0));
      await tester.pump();
      await tester.tap(option(1, 1));
      await tester.pump();
      final second = find.byKey(const ValueKey('question_1'));
      await tester.tap(
        find.descendant(
          of: second,
          matching: find.widgetWithText(FilledButton, 'Проверить'),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: second, matching: find.text('Попробовать ещё раз')),
      );
      await tester.pump();
      final group = find.descendant(
        of: find.byKey(const ValueKey('question_0')),
        matching: find.byType(RadioGroup<int>),
      );
      expect(tester.widget<RadioGroup<int>>(group).groupValue, 0);
      expect(submit, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
