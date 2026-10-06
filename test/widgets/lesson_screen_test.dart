import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/models/lesson_completion.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Lesson fixture({int tasks = 0, bool quiz = false}) => Lesson(
  id: 'fixture',
  moduleId: 'module',
  order: 1,
  title: 'Fixture',
  description: '',
  estimatedMinutes: 1,
  completion: LessonCompletion(
    type: quiz ? 'quiz' : 'lesson',
    passingScore: quiz ? 80 : null,
  ),
  blocks: List.generate(
    tasks,
    (index) => QuestionLessonBlock(
      question: 'Question $index',
      answers: ['Yes', 'No'],
      correctAnswer: 0,
      explanation: 'Feedback',
    ),
  ),
);

Finder get completionButton =>
    find.widgetWithText(FilledButton, 'Завершить урок');
bool completionEnabled(WidgetTester tester, {bool quiz = false}) =>
    tester
        .widget<FilledButton>(
          find.widgetWithText(
            FilledButton,
            quiz ? 'Завершить проверку' : 'Завершить урок',
          ),
        )
        .onPressed !=
    null;

void answer(WidgetTester tester, int index, bool correct) {
  tester
      .widget<LessonBlockRenderer>(find.byType(LessonBlockRenderer).at(index))
      .onAnswered(correct);
}

Future<void> showLesson(WidgetTester tester, Lesson lesson) async {
  // Keep the scoring fixture mounted without scrolling through 13 task cards.
  await tester.binding.setSurfaceSize(const Size(800, 14000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: LessonScreen(lesson: lesson)));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('zero tasks enables explicit completion without autosave', (
    tester,
  ) async {
    await showLesson(tester, fixture());
    expect(completionEnabled(tester), isTrue);
    expect(await ProgressService().getCompletedLessons(), isEmpty);
  });

  testWidgets(
    'one task incorrect, retry and correct propagate from question widget',
    (tester) async {
      await showLesson(tester, fixture(tasks: 1));
      expect(completionEnabled(tester), isFalse);
      await tester.tap(find.text('No'));
      await tester.pump();
      await tester.tap(find.text('Проверить'));
      await tester.pump();
      expect(completionEnabled(tester), isFalse);
      await tester.ensureVisible(find.text('Попробовать ещё раз'));
      await tester.tap(find.text('Попробовать ещё раз'));
      await tester.pump();
      expect(find.text('0 / 1'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.tap(find.text('Проверить'));
      await tester.pump();
      expect(completionEnabled(tester), isTrue);
      expect(await ProgressService().getCompletedLessons(), isEmpty);
    },
  );

  testWidgets(
    'multiple tasks require every result correct and retry removes result',
    (tester) async {
      await showLesson(tester, fixture(tasks: 3));
      answer(tester, 0, true);
      answer(tester, 1, false);
      await tester.pump();
      expect(completionEnabled(tester), isFalse);
      answer(tester, 2, true);
      await tester.pump();
      expect(completionEnabled(tester), isFalse);
      tester
          .widget<LessonBlockRenderer>(find.byType(LessonBlockRenderer).at(1))
          .onRetry();
      await tester.pump();
      expect(completionEnabled(tester), isFalse);
      answer(tester, 1, true);
      await tester.pump();
      expect(completionEnabled(tester), isTrue);
      expect(await ProgressService().getCompletedLessons(), isEmpty);
    },
  );

  for (final boundary in [
    (5, 3, 60, false),
    (5, 4, 80, true),
    (13, 10, 77, false),
    (13, 11, 85, true),
    (12, 9, 75, false),
    (12, 10, 83, true),
  ]) {
    testWidgets('quiz ${boundary.$2}/${boundary.$1} rounds to ${boundary.$3}', (
      tester,
    ) async {
      await showLesson(tester, fixture(tasks: boundary.$1, quiz: true));
      for (var i = 0; i < boundary.$1; i++) {
        answer(tester, i, i < boundary.$2);
      }
      await tester.pump();
      expect(find.text('${boundary.$3}%'), findsOneWidget);
      expect(completionEnabled(tester, quiz: true), boundary.$4);
      expect(await ProgressService().getCompletedLessons(), isEmpty);
    });
  }

  testWidgets(
    'explicit completion returns true and parent refresh reads saved ID',
    (tester) async {
      bool? returned;
      Set<String> refreshed = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(lesson: fixture()),
                    ),
                  );
                  if (returned == true) {
                    refreshed = await ProgressService().getCompletedLessons();
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(completionButton);
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(refreshed, {'fixture'});
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets('back without explicit completion saves nothing', (tester) async {
    await showLesson(tester, fixture(tasks: 1));
    answer(tester, 0, true);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(await ProgressService().getCompletedLessons(), isEmpty);
  });
}
