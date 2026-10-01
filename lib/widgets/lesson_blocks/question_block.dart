import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';

class QuestionBlock extends StatefulWidget {
  final QuestionLessonBlock block;

  /// Сообщает LessonScreen результат проверенного ответа.
  final ValueChanged<bool>? onAnswered;

  /// Сообщает LessonScreen, что пользователь сбросил ответ
  /// и собирается попробовать ещё раз.
  final VoidCallback? onRetry;

  const QuestionBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<QuestionBlock> createState() => _QuestionBlockState();
}

class _QuestionBlockState extends State<QuestionBlock> {
  int? selectedAnswer;
  bool checked = false;

  void checkAnswer() {
    if (selectedAnswer == null) {
      return;
    }

    final isCorrect = selectedAnswer == widget.block.correctAnswer;

    setState(() {
      checked = true;
    });

    widget.onAnswered?.call(isCorrect);
  }

  void retry() {
    setState(() {
      selectedAnswer = null;
      checked = false;
    });

    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final answers = widget.block.answers;

    final isCorrect = selectedAnswer == widget.block.correctAnswer;

    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.quiz_outlined),
                SizedBox(width: 8),
                Text(
                  'Проверь себя',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              widget.block.question,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 12),

            RadioGroup<int>(
              groupValue: selectedAnswer,
              onChanged: (int? value) {
                if (checked || value == null) {
                  return;
                }

                setState(() {
                  selectedAnswer = value;
                });
              },
              child: Column(
                children: List.generate(answers.length, (index) {
                  return RadioListTile<int>(
                    value: index,
                    enabled: !checked,
                    title: Text(answers[index]),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8),

            FilledButton(
              onPressed: selectedAnswer == null || checked ? null : checkAnswer,
              child: const Text('Проверить'),
            ),

            if (checked) ...[
              const SizedBox(height: 16),

              Text(
                isCorrect ? '✓ Правильно!' : '✗ Неправильно',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 8),

              Text(widget.block.explanation),

              if (!isCorrect) ...[
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Попробовать ещё раз'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
