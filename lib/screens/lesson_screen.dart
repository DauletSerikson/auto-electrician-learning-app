import 'package:flutter/material.dart';

import '../domain/lesson_attempt.dart';
import '../models/lesson.dart';
import '../services/progress_service.dart';
import '../widgets/lesson_block_renderer.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final Map<int, bool> taskResults = {};
  bool saving = false;
  bool saveFailed = false;

  Future<void> completeLesson() async {
    if (saving || !canCompleteLesson) return;
    setState(() {
      saving = true;
      saveFailed = false;
    });
    try {
      await ProgressService().completeLesson(widget.lesson.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        saveFailed = true;
      });
      return;
    }
    if (!mounted) return;
    // Explicit pop returns the confirmed result; PopScope blocks user back
    // while persistence is pending.
    Navigator.of(context).pop(true);
  }

  LessonAttempt get attempt =>
      evaluateLessonAttempt(widget.lesson, taskResults);
  int get totalTasks => attempt.totalTasks;
  int get answeredTasks => attempt.answeredTasks;
  int get correctAnswers => attempt.correctTasks;
  bool get allTasksAnswered => attempt.allAnswered;
  bool get allTasksCorrect => attempt.allCorrect;
  double get testScore => attempt.scoreFraction;
  int get scorePercent => attempt.scorePercent;
  int get passingScore => attempt.passingScore;
  bool get passedQuiz => attempt.passedQuiz;
  bool get canCompleteLesson => attempt.canComplete;

  void registerAnswer(int blockIndex, bool isCorrect) {
    setState(() {
      taskResults[blockIndex] = isCorrect;
    });
  }

  void resetAnswer(int blockIndex) {
    setState(() {
      taskResults.remove(blockIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '≈ ${lesson.estimatedMinutes} мин.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (lesson.completion.isQuiz) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Итоговая проверка • '
                    'проходной балл '
                    '$passingScore%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                ...List.generate(lesson.blocks.length, (index) {
                  return LessonBlockRenderer(
                    block: lesson.blocks[index],
                    blockIndex: index,
                    onAnswered: (isCorrect) {
                      registerAnswer(index, isCorrect);
                    },
                    onRetry: () {
                      resetAnswer(index);
                    },
                  );
                }),
                if (totalTasks > 0) buildTestResult(context),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canCompleteLesson && !saving
                      ? completeLesson
                      : null,
                  child: Text(
                    lesson.completion.isQuiz
                        ? 'Завершить проверку'
                        : 'Завершить урок',
                  ),
                ),
                if (saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const Text(
                    'Сохранение прогресса…',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (saveFailed) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Не удалось сохранить прогресс. Попробуй завершить урок ещё раз.',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (!canCompleteLesson) ...[
                  const SizedBox(height: 8),
                  buildCompletionHint(context),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCompletionHint(BuildContext context) {
    String message;

    if (!allTasksAnswered) {
      message =
          'Выполни все задания, '
          'чтобы завершить урок.';
    } else if (widget.lesson.completion.isQuiz && !passedQuiz) {
      message =
          'Для прохождения необходимо набрать '
          'не менее $passingScore%. '
          'Исправь неправильные ответы.';
    } else if (!widget.lesson.completion.isQuiz && !allTasksCorrect) {
      message =
          'Исправь неправильные задания, '
          'чтобы завершить урок.';
    } else {
      message = '';
    }

    return Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget buildTestResult(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.lesson.completion.isQuiz
                  ? 'Итоговый результат'
                  : 'Результат',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выполнено'),
                Text(
                  '$answeredTasks / '
                  '$totalTasks',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Правильно'),
                Text(
                  '$correctAnswers / '
                  '$totalTasks',
                ),
              ],
            ),
            if (allTasksAnswered) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: testScore),
              const SizedBox(height: 12),
              Text(
                '$scorePercent%',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (widget.lesson.completion.isQuiz) ...[
                const SizedBox(height: 8),
                Text(
                  passedQuiz
                      ? '✓ Проверка пройдена'
                      : 'Нужно минимум '
                            '$passingScore%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: passedQuiz ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
