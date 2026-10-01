import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lesson_block.dart';

class CalculationBlock extends StatefulWidget {
  final CalculationLessonBlock block;

  final ValueChanged<bool>? onAnswered;
  final VoidCallback? onRetry;

  const CalculationBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<CalculationBlock> createState() => _CalculationBlockState();
}

class _CalculationBlockState extends State<CalculationBlock> {
  final TextEditingController controller = TextEditingController();

  bool checked = false;
  bool isCorrect = false;
  bool invalidInput = false;

  int wrongAttempts = 0;

  void checkAnswer() {
    final text = controller.text.trim().replaceAll(',', '.');

    final value = double.tryParse(text);

    if (value == null) {
      setState(() {
        invalidInput = true;
      });

      return;
    }

    final correctValue = widget.block.correctValue;
    final tolerance = widget.block.tolerance;

    final difference = (value - correctValue).abs();

    final result = difference <= tolerance;

    setState(() {
      invalidInput = false;
      checked = true;
      isCorrect = result;

      if (!result) {
        wrongAttempts++;
      }
    });

    widget.onAnswered?.call(result);
  }

  void retry() {
    setState(() {
      controller.clear();
      checked = false;
      isCorrect = false;
      invalidInput = false;
    });

    widget.onRetry?.call();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.block.unit;

    final showHint = checked && !isCorrect;

    final showExplanation = checked && (isCorrect || wrongAttempts >= 2);

    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.calculate_outlined),
                SizedBox(width: 8),
                Text(
                  'Реши задачу',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              widget.block.question,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !checked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Ответ',
                      hintText: 'Введите число',
                      border: const OutlineInputBorder(),
                      errorText: invalidInput ? 'Введите число' : null,
                    ),
                    onSubmitted: (_) {
                      if (!checked) {
                        checkAnswer();
                      }
                    },
                  ),
                ),

                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 12),

                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      unit,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            FilledButton(
              onPressed: checked ? null : checkAnswer,
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
            ],

            if (showHint) ...[
              const SizedBox(height: 8),

              Text(
                'Подсказка: '
                '${widget.block.hint}',
              ),
            ],

            if (showExplanation) ...[
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.block.explanation),
              ),
            ],

            if (checked && !isCorrect) ...[
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Попробовать ещё раз'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
