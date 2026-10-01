import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';

enum CurrentMeterMode { off, dcVoltage, current }

enum CurrentRedPort { voltageResistance, current }

enum CurrentConnection { disconnected, series, acrossBattery, acrossLamp }

class CurrentMeasurementBlock extends StatefulWidget {
  final CurrentMeasurementLessonBlock block;

  final ValueChanged<bool>? onAnswered;
  final VoidCallback? onRetry;

  const CurrentMeasurementBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<CurrentMeasurementBlock> createState() =>
      _CurrentMeasurementBlockState();
}

class _CurrentMeasurementBlockState extends State<CurrentMeasurementBlock> {
  CurrentMeterMode mode = CurrentMeterMode.off;

  CurrentRedPort redPort = CurrentRedPort.voltageResistance;

  CurrentConnection connection = CurrentConnection.disconnected;

  bool meterFuseBlown = false;

  bool checked = false;
  bool completed = false;

  double get sourceVoltage => widget.block.sourceVoltage;

  double get loadCurrent => widget.block.loadCurrent;

  double get meterFuseRating => widget.block.meterFuseRating;

  bool get meterConfiguredForCurrent {
    return mode == CurrentMeterMode.current &&
        redPort == CurrentRedPort.current;
  }

  bool get correctSetup {
    return !meterFuseBlown &&
        meterConfiguredForCurrent &&
        connection == CurrentConnection.series;
  }

  bool get dangerousBatteryConnection {
    return !meterFuseBlown &&
        meterConfiguredForCurrent &&
        connection == CurrentConnection.acrossBattery;
  }

  String get displayValue {
    if (meterFuseBlown) {
      return 'FUSE';
    }

    if (mode == CurrentMeterMode.off) {
      return '────';
    }

    if (dangerousBatteryConnection) {
      return '⚠';
    }

    if (mode == CurrentMeterMode.dcVoltage) {
      if (connection == CurrentConnection.acrossBattery) {
        return sourceVoltage.toStringAsFixed(2);
      }

      return '0.00';
    }

    if (mode == CurrentMeterMode.current) {
      if (redPort != CurrentRedPort.current) {
        return '----';
      }

      if (connection == CurrentConnection.series) {
        return loadCurrent.toStringAsFixed(2);
      }

      if (connection == CurrentConnection.acrossLamp) {
        return '⚠';
      }

      return '0.00';
    }

    return '----';
  }

  String get displayUnit {
    switch (mode) {
      case CurrentMeterMode.off:
        return 'OFF';

      case CurrentMeterMode.dcVoltage:
        return 'V DC';

      case CurrentMeterMode.current:
        return 'A';
    }
  }

  void changeMode(CurrentMeterMode newMode) {
    if (checked || meterFuseBlown) {
      return;
    }

    setState(() {
      mode = newMode;
    });

    evaluateDanger();
  }

  void changeRedPort(CurrentRedPort port) {
    if (checked || meterFuseBlown) {
      return;
    }

    setState(() {
      redPort = port;
    });

    evaluateDanger();
  }

  void changeConnection(CurrentConnection newConnection) {
    if (checked || meterFuseBlown) {
      return;
    }

    setState(() {
      connection = newConnection;
    });

    evaluateDanger();
  }

  void evaluateDanger() {
    if (!mounted) {
      return;
    }

    if (dangerousBatteryConnection) {
      setState(() {
        meterFuseBlown = true;
      });
    }
  }

  void replaceFuse() {
    if (checked) {
      return;
    }

    setState(() {
      meterFuseBlown = false;
      mode = CurrentMeterMode.off;
      redPort = CurrentRedPort.voltageResistance;
      connection = CurrentConnection.disconnected;
    });
  }

  void checkMeasurement() {
    if (checked || meterFuseBlown) {
      return;
    }

    final result = correctSetup;

    setState(() {
      checked = true;
      completed = result;
    });

    widget.onAnswered?.call(result);
  }

  void retry() {
    setState(() {
      mode = CurrentMeterMode.off;

      redPort = CurrentRedPort.voltageResistance;

      connection = CurrentConnection.disconnected;

      meterFuseBlown = false;

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
                const Icon(Icons.electric_meter_outlined),

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

            buildMeter(context),

            const SizedBox(height: 20),

            buildConfiguration(context),

            if (meterFuseBlown) ...[
              const SizedBox(height: 16),

              buildFuseWarning(context),
            ],

            const SizedBox(height: 16),

            FilledButton(
              onPressed: checked || meterFuseBlown ? null : checkMeasurement,
              child: const Text('Проверить измерение'),
            ),

            if (checked) ...[const SizedBox(height: 16), buildResult(context)],
          ],
        ),
      ),
    );
  }

  Widget buildCircuit(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final seriesMeter = connection == CurrentConnection.series;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'ЦЕПЬ ЛАМПЫ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.battery_full, size: 42),

              const SizedBox(width: 8),

              Text(
                '${sourceVoltage.toStringAsFixed(1)} V',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Icon(Icons.arrow_downward),

          const SizedBox(height: 8),

          if (seriesMeter)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.electric_meter_outlined),
                  SizedBox(height: 4),
                  Text('A', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'мультиметр включён\n'
                    'в разрыв цепи',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Провод питания'),
            ),

          const SizedBox(height: 8),

          const Icon(Icons.arrow_downward),

          const SizedBox(height: 8),

          const Icon(Icons.lightbulb, size: 54),

          const SizedBox(height: 4),

          Text(
            seriesMeter && meterConfiguredForCurrent && !meterFuseBlown
                ? 'Ток через лампу: '
                      '${loadCurrent.toStringAsFixed(2)} A'
                : 'Лампа',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          const Icon(Icons.arrow_downward),

          const SizedBox(height: 8),

          const Text('МАССА', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget buildMeter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline, width: 2),
        ),
        child: Column(
          children: [
            Container(
              height: 86,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: meterFuseBlown
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayValue,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
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
                buildModeChip(CurrentMeterMode.off, 'OFF'),

                buildModeChip(CurrentMeterMode.dcVoltage, 'V DC'),

                buildModeChip(CurrentMeterMode.current, 'A'),
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
                  port: CurrentRedPort.voltageResistance,
                ),

                buildRedPort(context, label: 'A', port: CurrentRedPort.current),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildModeChip(CurrentMeterMode value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: mode == value,
      onSelected: checked || meterFuseBlown
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
          ),
        ),

        const SizedBox(height: 6),

        const Text('COM', style: TextStyle(fontWeight: FontWeight.bold)),

        const Text('чёрный', style: TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget buildRedPort(
    BuildContext context, {
    required String label,
    required CurrentRedPort port,
  }) {
    final selected = redPort == port;

    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: checked || meterFuseBlown
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

            Text(
              selected ? 'красный' : '',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildConfiguration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Подключение мультиметра',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 8),

        RadioGroup<CurrentConnection>(
          groupValue: connection,
          onChanged: (CurrentConnection? value) {
            if (checked || meterFuseBlown) {
              return;
            }

            if (value == null) {
              return;
            }

            changeConnection(value);
          },
          child: Column(
            children: const [
              RadioListTile<CurrentConnection>(
                value: CurrentConnection.disconnected,
                title: Text('Не подключён'),
              ),

              RadioListTile<CurrentConnection>(
                value: CurrentConnection.series,
                title: Text(
                  'В разрыв цепи '
                  '(последовательно)',
                ),
              ),

              RadioListTile<CurrentConnection>(
                value: CurrentConnection.acrossBattery,
                title: Text(
                  'Между + и − '
                  'аккумулятора',
                ),
              ),

              RadioListTile<CurrentConnection>(
                value: CurrentConnection.acrossLamp,
                title: Text('Параллельно лампе'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildFuseWarning(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber, color: colorScheme.onErrorContainer),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  'ОПАСНАЯ ОШИБКА\n\n'
                  'Токовый вход мультиметра '
                  'подключён непосредственно '
                  'между плюсом и минусом '
                  'источника. В симуляторе '
                  'сработал предохранитель '
                  'токового входа.',
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: replaceFuse,
            icon: const Icon(Icons.build),
            label: const Text(
              'Заменить предохранитель '
              'мультиметра',
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
        child: Text(
          '✓ Правильно.\n\n'
          'Цепь была разорвана, '
          'а мультиметр включён '
          'последовательно с нагрузкой. '
          'Весь ток лампы проходит через '
          'измерительный тракт прибора.\n\n'
          'Показание: '
          '${loadCurrent.toStringAsFixed(2)} A.',
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
            buildErrorMessage(),
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

  String buildErrorMessage() {
    if (mode != CurrentMeterMode.current) {
      return '✗ Неправильный режим.\n\n'
          'Для этого задания необходимо '
          'измерить силу тока, поэтому '
          'выбери режим A.';
    }

    if (redPort != CurrentRedPort.current) {
      return '✗ Красный провод находится '
          'в VΩ.\n\n'
          'В нашем учебном мультиметре '
          'для этого измерения его нужно '
          'переставить в токовое '
          'гнездо A.';
    }

    if (connection == CurrentConnection.disconnected) {
      return '✗ Мультиметр не включён '
          'в электрическую цепь.';
    }

    if (connection == CurrentConnection.acrossLamp) {
      return '✗ Амперметр нельзя '
          'подключать параллельно '
          'потребителю.\n\n'
          'Чтобы измерить ток лампы, '
          'разорви цепь и включи '
          'мультиметр последовательно.';
    }

    return '✗ Для измерения тока '
        'мультиметр должен быть '
        'правильно настроен и включён '
        'последовательно с нагрузкой.';
  }
}
