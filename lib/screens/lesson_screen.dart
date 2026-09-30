import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/lesson_block.dart';
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

  bool isTaskBlock(LessonBlock block) {
    return block is QuestionLessonBlock ||
        block is CalculationLessonBlock ||
        block is MeasurementLessonBlock ||
        block is VoltageDropLessonBlock ||
        block is CurrentMeasurementLessonBlock ||
        block is DiagnosticCaseLessonBlock ||
        block is DiagnosticChoiceLessonBlock;
  }

  int get totalTasks {
    return widget.lesson.blocks.where(isTaskBlock).length;
  }

  int get answeredTasks {
    return taskResults.length;
  }

  int get correctAnswers {
    return taskResults.values.where((result) => result).length;
  }

  bool get allTasksAnswered {
    return totalTasks == 0 || answeredTasks == totalTasks;
  }

  bool get allTasksCorrect {
    return totalTasks == 0 || correctAnswers == totalTasks;
  }

  double get testScore {
    if (totalTasks == 0) {
      return 0;
    }

    return correctAnswers / totalTasks;
  }

  int get scorePercent {
    return (testScore * 100).round();
  }

  int get passingScore {
    return widget.lesson.completion.passingScore ?? 0;
  }

  bool get passedQuiz {
    if (!widget.lesson.completion.isQuiz) {
      return true;
    }

    if (!allTasksAnswered) {
      return false;
    }

    return scorePercent >= passingScore;
  }

  bool get canCompleteLesson {
    if (!allTasksAnswered) {
      return false;
    }

    if (widget.lesson.completion.isQuiz) {
      return passedQuiz;
    }

    return allTasksCorrect;
  }

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

    return Scaffold(
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
                onPressed: canCompleteLesson
                    ? () async {
                        await ProgressService().completeLesson(lesson.id);

                        if (!context.mounted) {
                          return;
                        }

                        Navigator.pop(context, true);
                      }
                    : null,
                child: Text(
                  lesson.completion.isQuiz
                      ? 'Завершить проверку'
                      : 'Завершить урок',
                ),
              ),
              if (!canCompleteLesson) ...[
                const SizedBox(height: 8),
                buildCompletionHint(context),
              ],
              const SizedBox(height: 32),
            ],
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
