import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';
import '../../simulation/diagnostic_case_measurements.dart';

class DiagnosticCaseBlock extends StatefulWidget {
  final DiagnosticCaseLessonBlock block;

  final ValueChanged<bool>? onAnswered;
  final VoidCallback? onRetry;

  const DiagnosticCaseBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<DiagnosticCaseBlock> createState() => _DiagnosticCaseBlockState();
}

class _DiagnosticCaseBlockState extends State<DiagnosticCaseBlock> {
  final List<DiagnosticMeasurementRecord> performedMeasurements = [];

  bool powered = true;
  bool checked = false;
  bool completed = false;

  DiagnosticMeasurementRecord? selectedMeasurement;

  double get sourceVoltage => widget.block.sourceVoltage;

  bool get hasPositiveWireOpen {
    return widget.block.faultType == 'positiveWireOpen';
  }

  bool get requiredTestsPerformed {
    return hasPerformed(DiagnosticTest.batteryVoltage) &&
        hasPerformed(DiagnosticTest.fuseOutputVoltage) &&
        hasPerformed(DiagnosticTest.lampPositiveVoltage) &&
        hasPerformed(DiagnosticTest.wireContinuity);
  }

  bool hasPerformed(DiagnosticTest test) =>
      performedMeasurements.any((record) => record.test == test);

  String formatResult(DiagnosticCaseMeasurementResult result) {
    return switch (result) {
      DiagnosticCaseVoltage(:final value) => '${value.toStringAsFixed(2)} V',
      DiagnosticCaseContinuity(:final resistance, :final beep) =>
        '${resistance.toStringAsFixed(1)} Ω${beep ? ' / БИП' : ''}',
      DiagnosticCaseOpenLoop() => 'OL',
      DiagnosticCaseForbidden() => 'НЕЛЬЗЯ: цепь запитана',
    };
  }

  String descriptionFor(DiagnosticTest test) {
    switch (test) {
      case DiagnosticTest.batteryVoltage:
        return 'Напряжение непосредственно '
            'между выводами аккумулятора.';

      case DiagnosticTest.fuseInputVoltage:
        return 'Напряжение на входной '
            'стороне предохранителя '
            'относительно массы.';

      case DiagnosticTest.fuseOutputVoltage:
        return 'Напряжение после '
            'предохранителя относительно '
            'массы.';

      case DiagnosticTest.lampPositiveVoltage:
        return 'Напряжение на плюсовом '
            'выводе лампы относительно '
            'массы.';

      case DiagnosticTest.lampGroundVoltage:
        return 'Потенциал точки массы '
            'лампы относительно массы '
            'аккумулятора.';

      case DiagnosticTest.wireContinuity:
        return 'Проверка участка провода '
            'между выходом предохранителя '
            'и плюсовым выводом лампы.';
    }
  }

  String labelFor(DiagnosticTest test) {
    switch (test) {
      case DiagnosticTest.batteryVoltage:
        return 'Напряжение АКБ';

      case DiagnosticTest.fuseInputVoltage:
        return 'До предохранителя';

      case DiagnosticTest.fuseOutputVoltage:
        return 'После предохранителя';

      case DiagnosticTest.lampPositiveVoltage:
        return 'Плюс лампы';

      case DiagnosticTest.lampGroundVoltage:
        return 'Масса лампы';

      case DiagnosticTest.wireContinuity:
        return 'Прозвонить провод';
    }
  }

  IconData iconFor(DiagnosticTest test) {
    switch (test) {
      case DiagnosticTest.batteryVoltage:
        return Icons.battery_full;

      case DiagnosticTest.fuseInputVoltage:
      case DiagnosticTest.fuseOutputVoltage:
        return Icons.electrical_services;

      case DiagnosticTest.lampPositiveVoltage:
        return Icons.lightbulb_outline;

      case DiagnosticTest.lampGroundVoltage:
        return Icons.electrical_services_outlined;

      case DiagnosticTest.wireContinuity:
        return Icons.cable;
    }
  }

  void performTest(DiagnosticTest test) {
    if (checked) {
      return;
    }

    final measurements = DiagnosticCaseMeasurements(
      faultType: widget.block.faultType,
      sourceVoltage: sourceVoltage,
      powered: powered,
    );
    final record = DiagnosticMeasurementRecord(
      test: test,
      result: measurements.resultFor(test),
    );
    setState(() {
      selectedMeasurement = record;
      final index = performedMeasurements.indexWhere(
        (previous) => previous.test == test,
      );
      if (index == -1) {
        performedMeasurements.add(record);
      } else {
        performedMeasurements[index] = record;
      }
    });
  }

  void togglePower() {
    if (checked) {
      return;
    }

    setState(() {
      powered = !powered;
      selectedMeasurement = null;
    });
  }

  void checkDiagnosis() {
    if (checked) {
      return;
    }

    final result = requiredTestsPerformed && !powered && hasPositiveWireOpen;

    setState(() {
      checked = true;
      completed = result;
    });

    widget.onAnswered?.call(result);
  }

  void retry() {
    setState(() {
      performedMeasurements.clear();
      selectedMeasurement = null;

      powered = true;
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
                const Icon(Icons.car_repair),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.block.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              widget.block.question,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 20),

            buildCircuit(context),

            const SizedBox(height: 20),

            buildTestPanel(context),

            if (selectedMeasurement != null) ...[
              const SizedBox(height: 16),
              buildMeasurementResult(context, selectedMeasurement!),
            ],

            const SizedBox(height: 20),

            buildHistory(context),

            const SizedBox(height: 20),

            FilledButton(
              onPressed: checked ? null : checkDiagnosis,
              child: const Text('Указать неисправность'),
            ),

            if (checked) ...[
              const SizedBox(height: 16),
              buildFinalResult(context),
            ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'СИМПТОМ: ЛАМПА НЕ ГОРИТ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              Chip(label: Text(powered ? 'ПИТАНИЕ ВКЛ.' : 'ОБЕСТОЧЕНО')),
            ],
          ),

          const SizedBox(height: 24),

          const Icon(Icons.battery_full, size: 46),

          Text('АКБ ${sourceVoltage.toStringAsFixed(1)} V'),

          buildLine(context),

          const Text(
            'ПРЕДОХРАНИТЕЛЬ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          buildLine(context),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('ПРОВОД'),
          ),

          buildLine(context),

          Icon(Icons.lightbulb_outline, size: 54, color: colorScheme.onSurface),

          const Text(
            'ЛАМПА НЕ ГОРИТ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          buildLine(context),

          const Text('МАССА', style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: checked ? null : togglePower,
            icon: Icon(powered ? Icons.power_off : Icons.power),
            label: Text(powered ? 'Обесточить цепь' : 'Подать питание'),
          ),
        ],
      ),
    );
  }

  Widget buildLine(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 4,
      height: 28,
      color: Theme.of(context).colorScheme.outline,
    );
  }

  Widget buildTestPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Выбери проверку',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DiagnosticTest.values.map((test) {
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

  Widget buildMeasurementResult(
    BuildContext context,
    DiagnosticMeasurementRecord record,
  ) {
    final test = record.test;
    final colorScheme = Theme.of(context).colorScheme;

    final unsafe = record.result is DiagnosticCaseForbidden;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unsafe
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelFor(test),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(descriptionFor(test)),

          const SizedBox(height: 12),

          Text(
            formatResult(record.result),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),

          if (unsafe) ...[
            const SizedBox(height: 8),

            const Text(
              '⚠ Прозвонку выполняют '
              'на обесточенной '
              'исследуемой цепи.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildHistory(BuildContext context) {
    if (performedMeasurements.isEmpty) {
      return Text(
        'Измерений пока нет.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Журнал измерений',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        ...performedMeasurements.map(
          (record) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(iconFor(record.test)),
            title: Text(labelFor(record.test)),
            trailing: Text(
              formatResult(record.result),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFinalResult(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✓ Неисправность найдена',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 8),

            Text(
              'Обрыв находится в плюсовом '
              'проводе между выходом '
              'предохранителя и лампой.\n\n'
              'После предохранителя питание '
              'есть, но до плюсового вывода '
              'лампы оно не доходит. '
              'После обесточивания прозвонка '
              'этого участка показывает OL.',
            ),
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
          child: Text(
            buildFailureMessage(),
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Начать диагностику заново'),
        ),
      ],
    );
  }

  String buildFailureMessage() {
    if (powered) {
      return 'Диагностика ещё не завершена.\n\n'
          'После измерений напряжения '
          'подозрительный участок следует '
          'обесточить перед проверкой '
          'его целостности.';
    }

    if (!hasPerformed(DiagnosticTest.batteryVoltage)) {
      return 'Ты ещё не проверил источник '
          'питания. Начни с понимания, '
          'исправен ли сам аккумулятор.';
    }

    if (!hasPerformed(DiagnosticTest.fuseOutputVoltage)) {
      return 'Нужно определить, выходит ли '
          'питание из предохранителя.';
    }

    if (!hasPerformed(DiagnosticTest.lampPositiveVoltage)) {
      return 'Нужно проверить, доходит ли '
          'питание непосредственно '
          'до плюсового вывода лампы.';
    }

    if (!hasPerformed(DiagnosticTest.wireContinuity)) {
      return 'Ты сузил область поиска. '
          'Теперь на обесточенной цепи '
          'проверь целостность участка '
          'между предохранителем и лампой.';
    }

    return 'Продолжи последовательную '
        'диагностику цепи.';
  }
}
