import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';
import '../../simulation/multimeter.dart';
import '../../simulation/battery_voltage_simulation.dart';
import '../../simulation/conductor_measurement_simulation.dart';

export '../../simulation/battery_voltage_simulation.dart' show BatteryTerminal;
export '../../simulation/conductor_measurement_simulation.dart' show WirePoint;

class MeasurementBlock extends StatefulWidget {
  final MeasurementLessonBlock block;

  final ValueChanged<bool>? onAnswered;
  final VoidCallback? onRetry;

  const MeasurementBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<MeasurementBlock> createState() => _MeasurementBlockState();
}

class _MeasurementBlockState extends State<MeasurementBlock> {
  MultimeterMode mode = MultimeterMode.off;

  MultimeterPort redPort = MultimeterPort.voltageResistance;

  BatteryTerminal redTerminal = BatteryTerminal.none;

  BatteryTerminal blackTerminal = BatteryTerminal.none;

  WirePoint redWirePoint = WirePoint.none;

  WirePoint blackWirePoint = WirePoint.none;

  late bool wireBroken;
  late bool circuitPowered;

  bool checked = false;
  bool completed = false;

  bool get isBatteryVoltage =>
      widget.block is BatteryVoltageMeasurementLessonBlock;
  bool get isWireResistance =>
      widget.block is WireResistanceMeasurementLessonBlock ||
      widget.block is ResistanceMeasurementLessonBlock;
  bool get isWireContinuity =>
      widget.block is WireContinuityMeasurementLessonBlock;
  bool get isWireMeasurement => widget.block is ConductorMeasurementLessonBlock;
  double get batteryVoltage =>
      (widget.block as BatteryVoltageMeasurementLessonBlock).sourceVoltage;
  double get goodResistance =>
      (widget.block as ConductorMeasurementLessonBlock).goodResistance;

  BatteryVoltageSimulation get batterySimulation => BatteryVoltageSimulation(
    mode: mode,
    redPort: redPort,
    redTerminal: redTerminal,
    blackTerminal: blackTerminal,
    sourceVoltage: batteryVoltage,
  );
  ConductorMeasurementSimulation get conductorSimulation =>
      ConductorMeasurementSimulation(
        mode: mode,
        redPort: redPort,
        redWirePoint: redWirePoint,
        blackWirePoint: blackWirePoint,
        powered: circuitPowered,
        broken: wireBroken,
        resistance: goodResistance,
        kind: switch (widget.block) {
          WireResistanceMeasurementLessonBlock() ||
          ResistanceMeasurementLessonBlock() =>
            ConductorMeasurementKind.resistance,
          WireContinuityMeasurementLessonBlock() =>
            ConductorMeasurementKind.continuity,
          _ => throw StateError('Not a conductor measurement exercise'),
        },
      );

  @override
  void initState() {
    super.initState();

    wireBroken = widget.block.initiallyBroken ?? false;

    circuitPowered = widget.block.initiallyPowered ?? false;
  }

  bool get wireProbesAcrossWire =>
      isWireMeasurement && conductorSimulation.probesAcrossWire;
  bool get unsafeCurrentConnection =>
      isBatteryVoltage && batterySimulation.unsafeCurrentConnection;
  bool get unsafeOhmicMeasurement =>
      isWireMeasurement && conductorSimulation.unsafeOhmicMeasurement;
  bool get continuityBeep =>
      isWireMeasurement && conductorSimulation.continuityBeep;

  String get displayValue {
    if (isBatteryVoltage) {
      return switch (batterySimulation.readout) {
        BatteryOffReadout() => '────',
        BatteryWarningReadout() => '⚠',
        BatteryOpenLoopReadout() => 'OL',
        BatteryNumericReadout(:final value) => value.toStringAsFixed(2),
      };
    }
    if (isWireMeasurement) {
      return switch (conductorSimulation.readout) {
        ConductorOffReadout() => '────',
        ConductorWarningReadout() => '⚠',
        ConductorUnavailableReadout() => '----',
        ConductorOpenLoopReadout() => 'OL',
        ConductorNumericReadout(:final value) => value.toStringAsFixed(
          mode == MultimeterMode.resistance || mode == MultimeterMode.continuity
              ? 1
              : 2,
        ),
      };
    }
    return '----';
  }

  String get displayUnit {
    switch (mode) {
      case MultimeterMode.acVoltage:
        throw StateError('Unsupported mode for measurement_block: $mode');

      case MultimeterMode.off:
        return 'OFF';

      case MultimeterMode.dcVoltage:
        return 'V DC';

      case MultimeterMode.resistance:
        return 'Ω';

      case MultimeterMode.continuity:
        return '🔊';

      case MultimeterMode.current:
        return 'A';
    }
  }

  void changeMode(MultimeterMode newMode) {
    if (checked) {
      return;
    }

    setState(() {
      mode = newMode;
    });
  }

  void changeRedPort(MultimeterPort port) {
    if (checked) {
      return;
    }

    setState(() {
      redPort = port;
    });
  }

  void setRedTerminal(BatteryTerminal terminal) {
    if (checked) {
      return;
    }

    setState(() {
      redTerminal = terminal;
    });
  }

  void setBlackTerminal(BatteryTerminal terminal) {
    if (checked) {
      return;
    }

    setState(() {
      blackTerminal = terminal;
    });
  }

  void setRedWirePoint(WirePoint point) {
    if (checked) {
      return;
    }

    setState(() {
      redWirePoint = point;
    });
  }

  void setBlackWirePoint(WirePoint point) {
    if (checked) {
      return;
    }

    setState(() {
      blackWirePoint = point;
    });
  }

  void toggleWireFault() {
    if (checked) {
      return;
    }

    setState(() {
      wireBroken = !wireBroken;
    });
  }

  void togglePower() {
    if (checked) {
      return;
    }

    setState(() {
      circuitPowered = !circuitPowered;
    });
  }

  void checkMeasurement() {
    if (checked) {
      return;
    }

    final result = isBatteryVoltage
        ? batterySimulation.success
        : conductorSimulation.success;

    setState(() {
      checked = true;
      completed = result;
    });

    widget.onAnswered?.call(result);
  }

  void retry() {
    setState(() {
      mode = MultimeterMode.off;

      redPort = MultimeterPort.voltageResistance;

      redTerminal = BatteryTerminal.none;

      blackTerminal = BatteryTerminal.none;

      redWirePoint = WirePoint.none;

      blackWirePoint = WirePoint.none;

      wireBroken = widget.block.initiallyBroken ?? false;

      circuitPowered = widget.block.initiallyPowered ?? false;

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
                const Icon(Icons.electrical_services),
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

            if (isBatteryVoltage) buildBattery(context),

            if (isWireMeasurement) buildWire(context),

            const SizedBox(height: 20),

            buildMeter(context),

            if (mode == MultimeterMode.continuity) ...[
              const SizedBox(height: 12),
              buildContinuityIndicator(context),
            ],

            const SizedBox(height: 20),

            if (isBatteryVoltage) buildBatteryProbeControls(context),

            if (isWireMeasurement) buildWireProbeControls(context),

            if (unsafeCurrentConnection || unsafeOhmicMeasurement) ...[
              const SizedBox(height: 16),
              buildDangerWarning(context),
            ],

            const SizedBox(height: 16),

            FilledButton(
              onPressed: checked ? null : checkMeasurement,
              child: const Text('Проверить измерение'),
            ),

            if (checked) ...[const SizedBox(height: 16), buildResult(context)],
          ],
        ),
      ),
    );
  }

  Widget buildBattery(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'АККУМУЛЯТОР',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            'Источник: '
            '${batteryVoltage.toStringAsFixed(2)} V',
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBatteryTerminal(
                context,
                terminal: BatteryTerminal.positive,
                label: '+',
              ),
              buildBatteryTerminal(
                context,
                terminal: BatteryTerminal.negative,
                label: '−',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBatteryTerminal(
    BuildContext context, {
    required BatteryTerminal terminal,
    required String label,
  }) {
    final redHere = redTerminal == terminal;

    final blackHere = blackTerminal == terminal;

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outline, width: 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (redHere)
                Icon(Icons.circle, size: 20, color: colorScheme.error),

              if (blackHere)
                Icon(Icons.circle, size: 20, color: colorScheme.onSurface),

              if (!redHere && !blackHere)
                const Icon(Icons.radio_button_unchecked),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildWire(BuildContext context) {
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
                  'ИССЛЕДУЕМЫЙ ПРОВОД',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              Chip(label: Text(circuitPowered ? 'ПИТАНИЕ ВКЛ.' : 'ОБЕСТОЧЕНО')),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              buildWireEndpoint(context, 'A'),

              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      color: wireBroken
                          ? colorScheme.outlineVariant
                          : colorScheme.primary,
                    ),

                    if (wireBroken)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        color: colorScheme.surfaceContainerHighest,
                        child: Text(
                          'X',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                            fontSize: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              buildWireEndpoint(context, 'B'),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            wireBroken ? 'Состояние: ОБРЫВ' : 'Состояние: провод исправен',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: wireBroken ? colorScheme.error : null,
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: checked ? null : toggleWireFault,
                icon: Icon(wireBroken ? Icons.build : Icons.content_cut),
                label: Text(wireBroken ? 'Устранить обрыв' : 'Создать обрыв'),
              ),

              OutlinedButton.icon(
                onPressed: checked ? null : togglePower,
                icon: Icon(circuitPowered ? Icons.power_off : Icons.power),
                label: Text(
                  circuitPowered ? 'Отключить питание' : 'Подать питание',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildWireEndpoint(BuildContext context, String label) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 4,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildMeter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline, width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 86,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayValue,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),

                  Text(
                    displayUnit,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                buildModeChip(MultimeterMode.off, 'OFF'),

                buildModeChip(MultimeterMode.dcVoltage, 'V DC'),

                buildModeChip(MultimeterMode.resistance, 'Ω'),

                buildModeChip(MultimeterMode.continuity, '🔊'),

                buildModeChip(MultimeterMode.current, 'A'),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildComPort(context),

                buildRedPort(
                  context,
                  label: 'VΩ',
                  port: MultimeterPort.voltageResistance,
                ),

                buildRedPort(context, label: 'A', port: MultimeterPort.current),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildModeChip(MultimeterMode value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: mode == value,
      onSelected: checked
          ? null
          : (_) {
              changeMode(value);
            },
    );
  }

  Widget buildComPort(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.onSurface,
            border: Border.all(color: colorScheme.outline, width: 3),
          ),
        ),

        const SizedBox(height: 6),

        const Text('COM', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget buildRedPort(
    BuildContext context, {
    required String label,
    required MultimeterPort port,
  }) {
    final selected = redPort == port;

    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: checked
          ? null
          : () {
              changeRedPort(port);
            },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colorScheme.error : Colors.transparent,
                border: Border.all(
                  color: selected ? colorScheme.error : colorScheme.outline,
                  width: 3,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget buildContinuityIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String message;
    IconData icon;

    if (unsafeOhmicMeasurement) {
      message = 'Прозвонка на запитанной цепи недопустима.';
      icon = Icons.warning_amber;
    } else if (isBatteryVoltage) {
      message = 'Подключи щупы к разным концам провода.';
      icon = Icons.volume_off_outlined;
    } else if (isWireMeasurement && redPort != requiredRedPort(mode)) {
      message = 'Недействительное измерение: для прозвонки используй вход VΩ.';
      icon = Icons.warning_amber;
    } else if (isWireMeasurement && circuitPowered) {
      message = 'Перед прозвонкой отключи питание исследуемой цепи.';
      icon = Icons.warning_amber;
    } else if (isWireMeasurement &&
        conductorSimulation.probesConnected &&
        !wireProbesAcrossWire) {
      message =
          'БИП: оба щупа на одной точке, сопротивление 0 Ω. '
          'Для проверки участка A–B подключи щупы к разным концам провода.';
      icon = Icons.volume_up;
    } else if (!wireProbesAcrossWire) {
      message = 'Подключи щупы к разным концам провода.';
      icon = Icons.volume_off_outlined;
    } else if (continuityBeep) {
      message = 'БИП! Непрерывность обнаружена.';
      icon = Icons.volume_up;
    } else if (isWireMeasurement &&
        conductorSimulation.readout is ConductorOpenLoopReadout) {
      message = 'Сигнала нет. OL: обнаружен обрыв между A и B.';
      icon = Icons.volume_off;
    } else {
      message =
          'Сигнала нет: сопротивление превышает порог прозвонки. '
          'Это не означает обрыв.';
      icon = Icons.volume_off;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unsafeOhmicMeasurement
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBatteryProbeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Куда подключён красный щуп?',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 8),

        SegmentedButton<BatteryTerminal>(
          segments: const [
            ButtonSegment(
              value: BatteryTerminal.none,
              label: Text('Не подключён'),
            ),
            ButtonSegment(value: BatteryTerminal.positive, label: Text('+')),
            ButtonSegment(value: BatteryTerminal.negative, label: Text('−')),
          ],
          selected: {redTerminal},
          onSelectionChanged: checked
              ? null
              : (selection) {
                  setRedTerminal(selection.first);
                },
        ),

        const SizedBox(height: 16),

        Text(
          'Куда подключён чёрный щуп?',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 8),

        SegmentedButton<BatteryTerminal>(
          segments: const [
            ButtonSegment(
              value: BatteryTerminal.none,
              label: Text('Не подключён'),
            ),
            ButtonSegment(value: BatteryTerminal.positive, label: Text('+')),
            ButtonSegment(value: BatteryTerminal.negative, label: Text('−')),
          ],
          selected: {blackTerminal},
          onSelectionChanged: checked
              ? null
              : (selection) {
                  setBlackTerminal(selection.first);
                },
        ),
      ],
    );
  }

  Widget buildWireProbeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Куда подключён красный щуп?',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 8),

        SegmentedButton<WirePoint>(
          segments: const [
            ButtonSegment(value: WirePoint.none, label: Text('Не подключён')),
            ButtonSegment(value: WirePoint.pointA, label: Text('A')),
            ButtonSegment(value: WirePoint.pointB, label: Text('B')),
          ],
          selected: {redWirePoint},
          onSelectionChanged: checked
              ? null
              : (selection) {
                  setRedWirePoint(selection.first);
                },
        ),

        const SizedBox(height: 16),

        Text(
          'Куда подключён чёрный щуп?',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 8),

        SegmentedButton<WirePoint>(
          segments: const [
            ButtonSegment(value: WirePoint.none, label: Text('Не подключён')),
            ButtonSegment(value: WirePoint.pointA, label: Text('A')),
            ButtonSegment(value: WirePoint.pointB, label: Text('B')),
          ],
          selected: {blackWirePoint},
          onSelectionChanged: checked
              ? null
              : (selection) {
                  setBlackWirePoint(selection.first);
                },
        ),
      ],
    );
  }

  Widget buildDangerWarning(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String message;

    if (unsafeOhmicMeasurement) {
      message =
          'НЕПРАВИЛЬНОЕ ИЗМЕРЕНИЕ\n\n'
          'Режимы сопротивления и прозвонки '
          'используют внутренний источник '
          'мультиметра. Исследуемую цепь '
          'нужно предварительно обесточить. '
          'Внешнее напряжение может исказить '
          'результат и потенциально повредить '
          'прибор.';
    } else {
      message =
          'ОПАСНАЯ КОНФИГУРАЦИЯ\n\n'
          'Мультиметр установлен '
          'в режим измерения тока '
          'и подключён непосредственно '
          'между выводами аккумулятора. '
          'Через токовый тракт прибора '
          'может пойти очень большой ток.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: colorScheme.onErrorContainer),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
              '✓ Измерение выполнено правильно',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(buildSuccessExplanation()),
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
            buildErrorExplanation(),
            style: TextStyle(color: colorScheme.onErrorContainer),
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

  String buildSuccessExplanation() {
    if (isWireContinuity) {
      if (wireBroken) {
        return 'Режим прозвонки выбран '
            'правильно, цепь обесточена, '
            'а щупы подключены к точкам '
            'A и B. При обрыве прибор '
            'показывает OL и звукового '
            'сигнала нет.';
      }

      final threshold = ConductorMeasurementSimulation.continuityThreshold
          .toStringAsFixed(0);
      final measurementExplanation = continuityBeep
          ? 'Сопротивление ${goodResistance.toStringAsFixed(1)} Ω '
                'не превышает учебный порог прозвонки $threshold Ω, '
                'поэтому симулятор подаёт звуковой сигнал.'
          : 'Сопротивление превышает учебный порог прозвонки $threshold Ω, '
                'поэтому звукового сигнала нет. '
                'Отсутствие сигнала само по себе не означает обрыв.';

      return 'Режим прозвонки выбран '
          'правильно, цепь обесточена, '
          'а щупы подключены к разным '
          'концам провода. $measurementExplanation';
    }

    if (isWireResistance) {
      if (wireBroken) {
        return 'Режим Ω выбран правильно, '
            'цепь обесточена, а щупы '
            'подключены к разным концам '
            'провода. Показание OL '
            'указывает на отсутствие '
            'непрерывного электрического '
            'пути между A и B.';
      }

      return 'Режим Ω выбран правильно, '
          'цепь обесточена, а щупы '
          'подключены к концам провода. '
          'Получено низкое сопротивление '
          '${goodResistance.toStringAsFixed(1)} Ω.';
    }

    return 'Мультиметр установлен '
        'в режим V DC, красный '
        'измерительный провод находится '
        'в VΩ, красный щуп подключён '
        'к положительному выводу АКБ, '
        'а чёрный — к отрицательному. '
        'Показание: '
        '${batteryVoltage.toStringAsFixed(2)} V.';
  }

  String buildErrorExplanation() {
    if (isBatteryVoltage) {
      return buildBatteryErrorExplanation(batterySimulation.errorReason);
    }
    if (isWireMeasurement) {
      return buildConductorErrorExplanation(conductorSimulation.errorReason);
    }
    return '✗ Конфигурация измерения '
        'неверна. Проверь режим, '
        'гнёзда и положение щупов.';
  }

  String buildBatteryErrorExplanation(BatteryVoltageErrorReason reason) {
    return switch (reason) {
      BatteryVoltageErrorReason.unsafeCurrentConnection =>
        '✗ Выбран режим измерения '
            'тока и прибор подключён '
            'поперёк аккумулятора. '
            'Это опасная ошибка.',
      BatteryVoltageErrorReason.wrongMode =>
        '✗ Неправильный режим.\n\n'
            'Для измерения постоянного '
            'напряжения аккумулятора '
            'выбери V DC.',
      BatteryVoltageErrorReason.wrongPort =>
        '✗ Неправильное гнездо '
            'красного провода.\n\n'
            'Для измерения напряжения '
            'красный провод должен '
            'находиться в VΩ.',
      BatteryVoltageErrorReason.missingProbes =>
        '✗ Щупы подключены '
            'не полностью.',
      BatteryVoltageErrorReason.reversedPolarity =>
        '✗ Полярность щупов '
            'обратная.\n\n'
            'Для задания подключи '
            'красный щуп к +, '
            'а чёрный к −.',
      BatteryVoltageErrorReason.sameTerminal =>
        '✗ Оба щупа находятся '
            'на одном выводе. '
            'Напряжение измеряется '
            'между двумя точками.',
      BatteryVoltageErrorReason.incorrectSetup =>
        '✗ Конфигурация измерения '
            'неверна. Проверь режим, '
            'гнёзда и положение щупов.',
    };
  }

  String buildConductorErrorExplanation(
    ConductorMeasurementErrorReason reason,
  ) {
    return switch (reason) {
      ConductorMeasurementErrorReason.unsafeOhmicMeasurement =>
        '✗ Нельзя выполнять '
            'измерение сопротивления '
            'или прозвонку на запитанной '
            'исследуемой цепи.\n\n'
            'Сначала отключи питание.',
      ConductorMeasurementErrorReason.wrongMode =>
        isWireContinuity
            ? '✗ Неправильный режим.\n\n'
                  'Для этого задания выбери '
                  'режим прозвонки 🔊.'
            : '✗ Неправильный режим.\n\n'
                  'Для проверки сопротивления '
                  'провода выбери Ω.',
      ConductorMeasurementErrorReason.wrongPort =>
        isWireContinuity
            ? '✗ Неправильное гнездо '
                  'красного провода.\n\n'
                  'Для прозвонки используй '
                  'вход VΩ.'
            : '✗ Неправильное гнездо '
                  'красного провода.\n\n'
                  'Для измерения сопротивления '
                  'используй вход VΩ.',
      ConductorMeasurementErrorReason.powered =>
        isWireContinuity
            ? '✗ Перед прозвонкой '
                  'исследуемую цепь необходимо '
                  'обесточить.'
            : '✗ Сначала необходимо '
                  'обесточить исследуемую цепь.',
      ConductorMeasurementErrorReason.missingProbes =>
        isWireContinuity
            ? '✗ Подключи оба щупа '
                  'к исследуемому участку.'
            : '✗ Подключи оба щупа '
                  'к исследуемому проводу.',
      ConductorMeasurementErrorReason.samePoint =>
        isWireContinuity
            ? '✗ Один щуп должен '
                  'находиться на A, '
                  'а второй — на B.'
            : '✗ Щупы должны находиться '
                  'на разных концах '
                  'исследуемого участка: '
                  'один на A, другой на B.',
      ConductorMeasurementErrorReason.incorrectSetup =>
        '✗ Конфигурация измерения '
            'неверна. Проверь режим, '
            'гнёзда и положение щупов.',
    };
  }
}
