import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/lesson_block.dart';
import '../services/progress_service.dart';
import '../widgets/lesson_blocks/calculation_block.dart';
import '../widgets/lesson_blocks/circuit_block.dart';
import '../widgets/lesson_blocks/current_measurement_block.dart';
import '../widgets/lesson_blocks/diagnostic_case_block.dart';
import '../widgets/lesson_blocks/diagnostic_choice_block.dart';
import '../widgets/lesson_blocks/measurement_block.dart';
import '../widgets/lesson_blocks/multimeter_block.dart';
import '../widgets/lesson_blocks/question_block.dart';
import '../widgets/lesson_blocks/voltage_drop_block.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<LessonScreen> createState() =>
      _LessonScreenState();
}

class _LessonScreenState
    extends State<LessonScreen> {
  final Map<int, bool> taskResults = {};

  bool isTaskBlock(LessonBlock block) {
    return block.type == 'question' ||
        block.type == 'calculation' ||
        block.type == 'measurement' ||
        block.type == 'voltageDrop' ||
        block.type == 'currentMeasurement' ||
        block.type == 'diagnosticCase' ||
        block.type == 'diagnosticChoice';
  }

  int get totalTasks {
    return widget.lesson.blocks
        .where(isTaskBlock)
        .length;
  }

  int get answeredTasks {
    return taskResults.length;
  }

  int get correctAnswers {
    return taskResults.values
        .where((result) => result)
        .length;
  }

  bool get allTasksAnswered {
    return totalTasks == 0 ||
        answeredTasks == totalTasks;
  }

  bool get allTasksCorrect {
    return totalTasks == 0 ||
        correctAnswers == totalTasks;
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
    return widget
            .lesson.completion.passingScore ??
        0;
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

  void registerAnswer(
    int blockIndex,
    bool isCorrect,
  ) {
    setState(() {
      taskResults[blockIndex] = isCorrect;
    });
  }

  void resetAnswer(
    int blockIndex,
  ) {
    setState(() {
      taskResults.remove(blockIndex);
    });
  }

  Widget buildBlock(
    BuildContext context,
    LessonBlock block,
    int blockIndex,
  ) {
    switch (block.type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.only(
            bottom: 24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (block.title != null) ...[
                Text(
                  block.title!,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                block.content ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),
            ],
          ),
        );

      case 'remember':
        return Card(
          margin: const EdgeInsets.only(
            bottom: 24,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    block.content ?? '',
                  ),
                ),
              ],
            ),
          ),
        );

      case 'warning':
        return Card(
          margin: const EdgeInsets.only(
            bottom: 24,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.title ??
                            'Важно',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        block.content ?? '',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case 'image':
        if (block.asset == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 24,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                child: Image.asset(
                  block.asset!,
                  fit: BoxFit.cover,
                ),
              ),
              if (block.caption != null) ...[
                const SizedBox(height: 8),
                Text(
                  block.caption!,
                  textAlign:
                      TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ],
          ),
        );

      case 'circuit':
        return CircuitBlock(
          key: ValueKey(
            'circuit_$blockIndex',
          ),
          block: block,
        );

      case 'multimeter':
        return MultimeterBlock(
          key: ValueKey(
            'multimeter_$blockIndex',
          ),
          block: block,
        );

      case 'measurement':
        return MeasurementBlock(
          key: ValueKey(
            'measurement_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      case 'voltageDrop':
        return VoltageDropBlock(
          key: ValueKey(
            'voltage_drop_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      case 'currentMeasurement':
        return CurrentMeasurementBlock(
          key: ValueKey(
            'current_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      case 'diagnosticCase':
        return DiagnosticCaseBlock(
          key: ValueKey(
            'diagnostic_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      case 'diagnosticChoice':
        return DiagnosticChoiceBlock(
          key: ValueKey(
            'diagnostic_choice_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      case 'question':
        return QuestionBlock(
          key: ValueKey(
            'question_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      case 'calculation':
        return CalculationBlock(
          key: ValueKey(
            'calculation_$blockIndex',
          ),
          block: block,
          onAnswered: (isCorrect) {
            registerAnswer(
              blockIndex,
              isCorrect,
            );
          },
          onRetry: () {
            resetAnswer(blockIndex);
          },
        );

      default:
        return Padding(
          padding:
              const EdgeInsets.all(8),
          child: Text(
            'Неизвестный тип блока: '
            '${block.type}',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 760,
          ),
          child: ListView(
            padding:
                const EdgeInsets.all(20),
            children: [
              Text(
                lesson.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),

              const SizedBox(height: 8),

              Text(
                '≈ ${lesson.estimatedMinutes} мин.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),

              if (lesson
                  .completion.isQuiz) ...[
                const SizedBox(height: 8),

                Text(
                  'Итоговая проверка • '
                  'проходной балл '
                  '$passingScore%',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ],

              const SizedBox(height: 24),

              ...List.generate(
                lesson.blocks.length,
                (index) {
                  return buildBlock(
                    context,
                    lesson.blocks[index],
                    index,
                  );
                },
              ),

              if (totalTasks > 0)
                buildTestResult(context),

              const SizedBox(height: 24),

              FilledButton(
                onPressed: canCompleteLesson
                    ? () async {
                        await ProgressService()
                            .completeLesson(
                          lesson.id,
                        );

                        if (!context.mounted) {
                          return;
                        }

                        Navigator.pop(
                          context,
                          true,
                        );
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

                buildCompletionHint(
                  context,
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCompletionHint(
    BuildContext context,
  ) {
    String message;

    if (!allTasksAnswered) {
      message =
          'Выполни все задания, '
          'чтобы завершить урок.';
    } else if (widget
            .lesson.completion.isQuiz &&
        !passedQuiz) {
      message =
          'Для прохождения необходимо набрать '
          'не менее $passingScore%. '
          'Исправь неправильные ответы.';
    } else if (!widget
            .lesson.completion.isQuiz &&
        !allTasksCorrect) {
      message =
          'Исправь неправильные задания, '
          'чтобы завершить урок.';
    } else {
      message = '';
    }

    return Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodySmall,
    );
  }

  Widget buildTestResult(
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        top: 8,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.lesson
                      .completion.isQuiz
                  ? 'Итоговый результат'
                  : 'Результат',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
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
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
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

              LinearProgressIndicator(
                value: testScore,
              ),

              const SizedBox(height: 12),

              Text(
                '$scorePercent%',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),

              if (widget
                  .lesson
                  .completion
                  .isQuiz) ...[
                const SizedBox(height: 8),

                Text(
                  passedQuiz
                      ? '✓ Проверка пройдена'
                      : 'Нужно минимум '
                          '$passingScore%',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color: passedQuiz
                        ? Colors.green
                        : Colors.red,
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