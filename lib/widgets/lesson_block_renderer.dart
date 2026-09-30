import 'package:flutter/material.dart';

import '../models/lesson_block.dart';
import 'lesson_blocks/calculation_block.dart';
import 'lesson_blocks/circuit_block.dart';
import 'lesson_blocks/current_measurement_block.dart';
import 'lesson_blocks/diagnostic_case_block.dart';
import 'lesson_blocks/diagnostic_choice_block.dart';
import 'lesson_blocks/measurement_block.dart';
import 'lesson_blocks/multimeter_block.dart';
import 'lesson_blocks/question_block.dart';
import 'lesson_blocks/voltage_drop_block.dart';

class LessonBlockRenderer extends StatelessWidget {
  final LessonBlock block;
  final int blockIndex;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onRetry;

  const LessonBlockRenderer({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.onAnswered,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      TextLessonBlock block => _buildTextBlock(context, block),
      RememberLessonBlock block => _buildRememberBlock(block),
      WarningLessonBlock block => _buildWarningBlock(block),
      ImageLessonBlock block => _buildImageBlock(context, block),
      CircuitLessonBlock block => CircuitBlock(
        key: ValueKey('circuit_$blockIndex'),
        block: block,
      ),
      MultimeterLessonBlock block => MultimeterBlock(
        key: ValueKey('multimeter_$blockIndex'),
        block: block,
      ),
      MeasurementLessonBlock block => MeasurementBlock(
        key: ValueKey('measurement_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
      VoltageDropLessonBlock block => VoltageDropBlock(
        key: ValueKey('voltage_drop_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
      CurrentMeasurementLessonBlock block => CurrentMeasurementBlock(
        key: ValueKey('current_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
      DiagnosticCaseLessonBlock block => DiagnosticCaseBlock(
        key: ValueKey('diagnostic_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
      DiagnosticChoiceLessonBlock block => DiagnosticChoiceBlock(
        key: ValueKey('diagnostic_choice_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
      QuestionLessonBlock block => QuestionBlock(
        key: ValueKey('question_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
      CalculationLessonBlock block => CalculationBlock(
        key: ValueKey('calculation_$blockIndex'),
        block: block,
        onAnswered: onAnswered,
        onRetry: onRetry,
      ),
    };
  }

  Widget _buildTextBlock(BuildContext context, TextLessonBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(block.content, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildRememberBlock(RememberLessonBlock block) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(block.content)),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBlock(WarningLessonBlock block) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(block.content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBlock(BuildContext context, ImageLessonBlock block) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(block.asset, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Text(
            block.caption,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
