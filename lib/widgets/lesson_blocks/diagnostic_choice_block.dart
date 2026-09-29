import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';

enum DiagnosticChoiceTest {
  batteryVoltage,
  fuseInputVoltage,
  fuseOutputVoltage,
  lampPositiveVoltage,
  lampGroundVoltage,
}

class DiagnosticChoiceBlock extends StatefulWidget {
  final LessonBlock block;

  final ValueChanged<bool>? onAnswered;
  final VoidCallback? onRetry;

  const DiagnosticChoiceBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<DiagnosticChoiceBlock> createState() => _DiagnosticChoiceBlockState();
}

class _DiagnosticChoiceBlockState extends State<DiagnosticChoiceBlock> {
  final List<DiagnosticChoiceTest> performedTests = [];

  int? selectedDiagnosis;

  bool checked = false;
  bool completed = false;

  double get sourceVoltage => widget.block.sourceVoltage ?? 12.6;

  String get faultType => widget.block.faultType ?? 'positiveWireOpen';

  List<String> get diagnosisOptions => widget.block.diagnosisOptions ?? [];

  String labelFor(DiagnosticChoiceTest test) {
    switch (test) {
      case DiagnosticChoiceTest.batteryVoltage:
        return 'Напряжение АКБ';

      case DiagnosticChoiceTest.fuseInputVoltage:
        return 'До предохранителя';

      case DiagnosticChoiceTest.fuseOutputVoltage:
        return 'После предохранителя';

      case DiagnosticChoiceTest.lampPositiveVoltage:
        return 'Плюс лампы';

      case DiagnosticChoiceTest.lampGroundVoltage:
        return 'Масса лампы';
    }
  }

  IconData iconFor(DiagnosticChoiceTest test) {
    switch (test) {
      case DiagnosticChoiceTest.batteryVoltage:
        return Icons.battery_full;

      case DiagnosticChoiceTest.fuseInputVoltage:
      case DiagnosticChoiceTest.fuseOutputVoltage:
        return Icons.electrical_services;

      case DiagnosticChoiceTest.lampPositiveVoltage:
        return Icons.lightbulb_outline;

      case DiagnosticChoiceTest.lampGroundVoltage:
        return Icons.electrical_services_outlined;
    }
  }

  String resultFor(DiagnosticChoiceTest test) {
    switch (test) {
      case DiagnosticChoiceTest.batteryVoltage:
        return '${sourceVoltage.toStringAsFixed(2)} V';

      case DiagnosticChoiceTest.fuseInputVoltage:
        return '${sourceVoltage.toStringAsFixed(2)} V';

      case DiagnosticChoiceTest.fuseOutputVoltage:
        if (faultType == 'blownFuse') {
          return '0.00 V';
        }

        return '${sourceVoltage.toStringAsFixed(2)} V';

      case DiagnosticChoiceTest.lampPositiveVoltage:
        if (faultType == 'blownFuse' || faultType == 'positiveWireOpen') {
          return '0.00 V';
        }

        return '${sourceVoltage.toStringAsFixed(2)} V';

      case DiagnosticChoiceTest.lampGroundVoltage:
        if (faultType == 'groundOpen') {
          return '${sourceVoltage.toStringAsFixed(2)} V';
        }

        return '0.00 V';
    }
  }

  void performTest(DiagnosticChoiceTest test) {
    if (checked) {
      return;
    }

    setState(() {
      if (!performedTests.contains(test)) {
        performedTests.add(test);
      }
    });
  }

  void selectDiagnosis(int index) {
    if (checked) {
      return;
    }

    setState(() {
      selectedDiagnosis = index;
    });
  }

  void checkDiagnosis() {
    if (checked || selectedDiagnosis == null) {
      return;
    }

    final correct = widget.block.correctDiagnosis;

    if (correct == null) {
      return;
    }

    final result = selectedDiagnosis == correct;

    setState(() {
      checked = true;
      completed = result;
    });

    widget.onAnswered?.call(result);
  }

  void retry() {
    setState(() {
      performedTests.clear();
      selectedDiagnosis = null;

      checked = false;
      completed = false;
    });

    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.troubleshoot),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    widget.block.title ?? 'Диагностика',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              widget.block.question ?? 'Найди неисправность.',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 20),

            buildCircuit(context),

            const SizedBox(height: 20),

            buildMeasurements(context),

            const SizedBox(height: 20),

            buildMeasurementHistory(context),

            const SizedBox(height: 20),

            buildDiagnosisSelection(context),

            const SizedBox(height: 16),

            FilledButton(
              onPressed: checked || selectedDiagnosis == null
                  ? null
                  : checkDiagnosis,
              child: const Text('Проверить диагноз'),
            ),

            if (checked) ...[const SizedBox(height: 16), buildResult(context)],
          ],
        ),
      ),
    );
  }

  Widget buildCircuit(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('СИМПТОМ', style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 8),

          const Icon(Icons.lightbulb_outline, size: 64),

          const SizedBox(height: 8),

          const Text(
            'Лампа не горит',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),

          const SizedBox(height: 20),

          const Text('АКБ'),

          buildLine(context),

          const Text('ПРЕДОХРАНИТЕЛЬ'),

          buildLine(context),

          const Text('ПРОВОД'),

          buildLine(context),

          const Text('ЛАМПА'),

          buildLine(context),

          const Text('МАССА'),
        ],
      ),
    );
  }

  Widget buildLine(BuildContext context) {
    return Container(
      width: 4,
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Theme.of(context).colorScheme.outline,
    );
  }

  Widget buildMeasurements(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Доступные измерения',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DiagnosticChoiceTest.values.map((test) {
            return OutlinedButton.icon(
              onPressed: checked
                  ? null
                  : () {
                      performTest(test);
                    },
              icon: Icon(iconFor(test)),
              label: Text(labelFor(test)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget buildMeasurementHistory(BuildContext context) {
    if (performedTests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Измерений пока нет. '
          'Выбери точки проверки выше.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Результаты измерений',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        ...performedTests.map((test) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(iconFor(test)),
            title: Text(labelFor(test)),
            trailing: Text(
              resultFor(test),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }),
      ],
    );
  }

  Widget buildDiagnosisSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Твой диагноз',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        RadioGroup<int>(
          groupValue: selectedDiagnosis,
          onChanged: (int? value) {
            if (checked || value == null) {
              return;
            }

            selectDiagnosis(value);
          },
          child: Column(
            children: List.generate(diagnosisOptions.length, (index) {
              return RadioListTile<int>(
                value: index,
                enabled: !checked,
                title: Text(diagnosisOptions[index]),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget buildResult(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✓ Диагноз правильный',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            if (widget.block.explanation != null) ...[
              const SizedBox(height: 8),

              Text(widget.block.explanation!),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '✗ Диагноз не подтверждается '
            'результатами измерений.\n\n'
            'Посмотри, между какими '
            'контрольными точками '
            'изменяется ожидаемое '
            'напряжение.',
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Попробовать ещё раз'),
        ),
      ],
    );
  }
}
