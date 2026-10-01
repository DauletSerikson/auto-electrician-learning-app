import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';

enum MeasurementMode { off, dcVoltage, resistance, continuity, current }

enum MeasurementRedPort { voltageResistance, current }

enum BatteryTerminal { none, positive, negative }

enum WirePoint { none, pointA, pointB }

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
  static const double continuityThreshold = 50.0;

  MeasurementMode mode = MeasurementMode.off;

  MeasurementRedPort redPort = MeasurementRedPort.voltageResistance;

  BatteryTerminal redTerminal = BatteryTerminal.none;

  BatteryTerminal blackTerminal = BatteryTerminal.none;

  WirePoint redWirePoint = WirePoint.none;

  WirePoint blackWirePoint = WirePoint.none;

  late bool wireBroken;
  late bool circuitPowered;

  bool checked = false;
  bool completed = false;

  bool get isBatteryVoltage {
    return widget.block.measurementType == 'batteryVoltage';
  }

  bool get isWireResistance {
    return widget.block.measurementType == 'wireResistance';
  }

  bool get isWireContinuity {
    return widget.block.measurementType == 'wireContinuity';
  }

  bool get isWireMeasurement {
    return isWireResistance || isWireContinuity;
  }

  double get batteryVoltage => widget.block.sourceVoltage ?? 12.6;

  double get goodResistance => widget.block.goodResistance ?? 0.3;

  @override
  void initState() {
    super.initState();

    wireBroken = widget.block.initiallyBroken ?? false;

    circuitPowered = widget.block.initiallyPowered ?? false;
  }

  bool get batteryProbesConnected {
    return redTerminal != BatteryTerminal.none &&
        blackTerminal != BatteryTerminal.none;
  }

  bool get batteryProbesDifferent {
    return batteryProbesConnected && redTerminal != blackTerminal;
  }

  bool get wireProbesConnected {
    return redWirePoint != WirePoint.none && blackWirePoint != WirePoint.none;
  }

  bool get wireProbesAcrossWire {
    return wireProbesConnected && redWirePoint != blackWirePoint;
  }

  bool get correctVoltageSetup {
    return isBatteryVoltage &&
        mode == MeasurementMode.dcVoltage &&
        redPort == MeasurementRedPort.voltageResistance &&
        redTerminal == BatteryTerminal.positive &&
        blackTerminal == BatteryTerminal.negative;
  }

  bool get reversedVoltageSetup {
    return isBatteryVoltage &&
        mode == MeasurementMode.dcVoltage &&
        redPort == MeasurementRedPort.voltageResistance &&
        redTerminal == BatteryTerminal.negative &&
        blackTerminal == BatteryTerminal.positive;
  }

  bool get unsafeCurrentConnection {
    return isBatteryVoltage &&
        mode == MeasurementMode.current &&
        redPort == MeasurementRedPort.current &&
        batteryProbesDifferent;
  }

  bool get unsafeOhmicMeasurement {
    return isWireMeasurement &&
        circuitPowered &&
        (mode == MeasurementMode.resistance ||
            mode == MeasurementMode.continuity) &&
        wireProbesConnected;
  }

  bool get correctResistanceSetup {
    return isWireResistance &&
        !circuitPowered &&
        mode == MeasurementMode.resistance &&
        redPort == MeasurementRedPort.voltageResistance &&
        wireProbesAcrossWire;
  }

  bool get correctContinuitySetup {
    return isWireContinuity &&
        !circuitPowered &&
        mode == MeasurementMode.continuity &&
        redPort == MeasurementRedPort.voltageResistance &&
        wireProbesAcrossWire;
  }

  bool get continuityBeep {
    return mode == MeasurementMode.continuity &&
        !circuitPowered &&
        redPort == MeasurementRedPort.voltageResistance &&
        wireProbesAcrossWire &&
        !wireBroken &&
        goodResistance <= continuityThreshold;
  }

  String get displayValue {
    if (mode == MeasurementMode.off) {
      return '────';
    }

    if (unsafeCurrentConnection || unsafeOhmicMeasurement) {
      return '⚠';
    }

    if (isBatteryVoltage) {
      return batteryDisplayValue;
    }

    if (isWireMeasurement) {
      return wireDisplayValue;
    }

    return '----';
  }

  String get batteryDisplayValue {
    if (mode == MeasurementMode.dcVoltage &&
        redPort == MeasurementRedPort.voltageResistance) {
      if (correctVoltageSetup) {
        return batteryVoltage.toStringAsFixed(2);
      }

      if (reversedVoltageSetup) {
        return (-batteryVoltage).toStringAsFixed(2);
      }

      return '0.00';
    }

    if (mode == MeasurementMode.resistance ||
        mode == MeasurementMode.continuity) {
      return 'OL';
    }

    return '0.00';
  }

  String get wireDisplayValue {
    if (mode != MeasurementMode.resistance &&
        mode != MeasurementMode.continuity) {
      return '0.00';
    }

    if (redPort != MeasurementRedPort.voltageResistance) {
      return '----';
    }

    if (!wireProbesAcrossWire) {
      return 'OL';
    }

    if (circuitPowered) {
      return '⚠';
    }

    if (wireBroken) {
      return 'OL';
    }

    return goodResistance.toStringAsFixed(1);
  }

  String get displayUnit {
    switch (mode) {
      case MeasurementMode.off:
        return 'OFF';

      case MeasurementMode.dcVoltage:
        return 'V DC';

      case MeasurementMode.resistance:
        return 'Ω';

      case MeasurementMode.continuity:
        return '🔊';

      case MeasurementMode.current:
        return 'A';
    }
  }

  void changeMode(MeasurementMode newMode) {
    if (checked) {
      return;
    }

    setState(() {
      mode = newMode;
    });
  }

  void changeRedPort(MeasurementRedPort port) {
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

    bool result = false;

    if (isBatteryVoltage) {
      result = correctVoltageSetup;
    }

    if (isWireResistance) {
      result = correctResistanceSetup;
    }

    if (isWireContinuity) {
      result = correctContinuitySetup;
    }

    setState(() {
      checked = true;
      completed = result;
    });

    widget.onAnswered?.call(result);
  }

  void retry() {
    setState(() {
      mode = MeasurementMode.off;

      redPort = MeasurementRedPort.voltageResistance;

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

            if (mode == MeasurementMode.continuity) ...[
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
                buildModeChip(MeasurementMode.off, 'OFF'),

                buildModeChip(MeasurementMode.dcVoltage, 'V DC'),

                buildModeChip(MeasurementMode.resistance, 'Ω'),

                buildModeChip(MeasurementMode.continuity, '🔊'),

                buildModeChip(MeasurementMode.current, 'A'),
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
                  port: MeasurementRedPort.voltageResistance,
                ),

                buildRedPort(
                  context,
                  label: 'A',
                  port: MeasurementRedPort.current,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildModeChip(MeasurementMode value, String label) {
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
    required MeasurementRedPort port,
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
    } else if (!wireProbesAcrossWire) {
      message = 'Подключи щупы к разным концам провода.';
      icon = Icons.volume_off_outlined;
    } else if (continuityBeep) {
      message = 'БИП! Непрерывность обнаружена.';
      icon = Icons.volume_up;
    } else {
      message = 'Сигнала нет. Непрерывный путь не обнаружен.';
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

      return 'Режим прозвонки выбран '
          'правильно, цепь обесточена, '
          'а щупы подключены к разным '
          'концам провода. Сопротивление '
          '${goodResistance.toStringAsFixed(1)} Ω '
          'ниже учебного порога '
          '${continuityThreshold.toStringAsFixed(0)} Ω, '
          'поэтому симулятор подаёт '
          'звуковой сигнал.';
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
    if (unsafeOhmicMeasurement) {
      return '✗ Нельзя выполнять '
          'измерение сопротивления '
          'или прозвонку на запитанной '
          'исследуемой цепи.\n\n'
          'Сначала отключи питание.';
    }

    if (unsafeCurrentConnection) {
      return '✗ Выбран режим измерения '
          'тока и прибор подключён '
          'поперёк аккумулятора. '
          'Это опасная ошибка.';
    }

    if (isWireContinuity) {
      if (mode != MeasurementMode.continuity) {
        return '✗ Неправильный режим.\n\n'
            'Для этого задания выбери '
            'режим прозвонки 🔊.';
      }

      if (redPort != MeasurementRedPort.voltageResistance) {
        return '✗ Неправильное гнездо '
            'красного провода.\n\n'
            'Для прозвонки используй '
            'вход VΩ.';
      }

      if (circuitPowered) {
        return '✗ Перед прозвонкой '
            'исследуемую цепь необходимо '
            'обесточить.';
      }

      if (!wireProbesConnected) {
        return '✗ Подключи оба щупа '
            'к исследуемому участку.';
      }

      if (!wireProbesAcrossWire) {
        return '✗ Один щуп должен '
            'находиться на A, '
            'а второй — на B.';
      }
    }

    if (isWireResistance) {
      if (mode != MeasurementMode.resistance) {
        return '✗ Неправильный режим.\n\n'
            'Для проверки сопротивления '
            'провода выбери Ω.';
      }

      if (redPort != MeasurementRedPort.voltageResistance) {
        return '✗ Неправильное гнездо '
            'красного провода.\n\n'
            'Для измерения сопротивления '
            'используй вход VΩ.';
      }

      if (circuitPowered) {
        return '✗ Сначала необходимо '
            'обесточить исследуемую цепь.';
      }

      if (!wireProbesConnected) {
        return '✗ Подключи оба щупа '
            'к исследуемому проводу.';
      }

      if (!wireProbesAcrossWire) {
        return '✗ Щупы должны находиться '
            'на разных концах '
            'исследуемого участка: '
            'один на A, другой на B.';
      }
    }

    if (isBatteryVoltage) {
      if (mode != MeasurementMode.dcVoltage) {
        return '✗ Неправильный режим.\n\n'
            'Для измерения постоянного '
            'напряжения аккумулятора '
            'выбери V DC.';
      }

      if (redPort != MeasurementRedPort.voltageResistance) {
        return '✗ Неправильное гнездо '
            'красного провода.\n\n'
            'Для измерения напряжения '
            'красный провод должен '
            'находиться в VΩ.';
      }

      if (!batteryProbesConnected) {
        return '✗ Щупы подключены '
            'не полностью.';
      }

      if (reversedVoltageSetup) {
        return '✗ Полярность щупов '
            'обратная.\n\n'
            'Для задания подключи '
            'красный щуп к +, '
            'а чёрный к −.';
      }

      if (redTerminal == blackTerminal) {
        return '✗ Оба щупа находятся '
            'на одном выводе. '
            'Напряжение измеряется '
            'между двумя точками.';
      }
    }

    return '✗ Конфигурация измерения '
        'неверна. Проверь режим, '
        'гнёзда и положение щупов.';
  }
}
