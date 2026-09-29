import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';

enum VoltageDropPoint {
  batteryPositive,
  afterFault,
  ground,
}

class VoltageDropBlock extends StatefulWidget {
  final LessonBlock block;

  final ValueChanged<bool>? onAnswered;
  final VoidCallback? onRetry;

  const VoltageDropBlock({
    super.key,
    required this.block,
    this.onAnswered,
    this.onRetry,
  });

  @override
  State<VoltageDropBlock> createState() =>
      _VoltageDropBlockState();
}

class _VoltageDropBlockState
    extends State<VoltageDropBlock> {
  bool loadOn = true;

  VoltageDropPoint? redPoint;
  VoltageDropPoint? blackPoint;

  bool checked = false;
  bool completed = false;

  double get sourceVoltage =>
      widget.block.sourceVoltage ?? 12.6;

  double get faultVoltageDrop =>
      widget.block.faultVoltageDrop ?? 4.0;

  double get loadVoltage =>
      sourceVoltage - faultVoltageDrop;

  @override
  void initState() {
    super.initState();

    loadOn =
        widget.block.initiallyLoaded ??
            true;
  }

  double potentialAt(
    VoltageDropPoint point,
  ) {
    if (!loadOn) {
      switch (point) {
        case VoltageDropPoint.batteryPositive:
          return sourceVoltage;

        case VoltageDropPoint.afterFault:
          return sourceVoltage;

        case VoltageDropPoint.ground:
          return 0;
      }
    }

    switch (point) {
      case VoltageDropPoint.batteryPositive:
        return sourceVoltage;

      case VoltageDropPoint.afterFault:
        return loadVoltage;

      case VoltageDropPoint.ground:
        return 0;
    }
  }

  double? get meterReading {
    if (redPoint == null ||
        blackPoint == null) {
      return null;
    }

    return potentialAt(redPoint!) -
        potentialAt(blackPoint!);
  }

  bool get probesConnected {
    return redPoint != null &&
        blackPoint != null;
  }

  bool get measuringAcrossFault {
    if (!probesConnected) {
      return false;
    }

    return redPoint ==
            VoltageDropPoint
                .batteryPositive &&
        blackPoint ==
            VoltageDropPoint.afterFault;
  }

  bool get correctSetup {
    return loadOn &&
        measuringAcrossFault;
  }

  void setRedPoint(
    VoltageDropPoint point,
  ) {
    if (checked) {
      return;
    }

    setState(() {
      redPoint = point;
    });
  }

  void setBlackPoint(
    VoltageDropPoint point,
  ) {
    if (checked) {
      return;
    }

    setState(() {
      blackPoint = point;
    });
  }

  void toggleLoad() {
    if (checked) {
      return;
    }

    setState(() {
      loadOn = !loadOn;
    });
  }

  void checkMeasurement() {
    if (checked) {
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
      loadOn =
          widget.block.initiallyLoaded ??
              true;

      redPoint = null;
      blackPoint = null;

      checked = false;
      completed = false;
    });

    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        top: 8,
        bottom: 24,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.troubleshoot,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.block.title ??
                        'Падение напряжения',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              widget.block.question ??
                  'Выполни измерение.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 20),

            buildCircuit(context),

            const SizedBox(height: 20),

            buildMeter(context),

            const SizedBox(height: 20),

            buildProbeControls(context),

            const SizedBox(height: 16),

            FilledButton(
              onPressed: checked
                  ? null
                  : checkMeasurement,
              child: const Text(
                'Проверить измерение',
              ),
            ),

            if (checked) ...[
              const SizedBox(height: 16),
              buildResult(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildCircuit(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ЦЕПЬ ЛАМПЫ',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              Chip(
                label: Text(
                  loadOn
                      ? 'ЛАМПА ВКЛ.'
                      : 'ЛАМПА ВЫКЛ.',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          buildCircuitPoint(
            context,
            title: 'A',
            subtitle:
                'АКБ +\n${sourceVoltage.toStringAsFixed(1)} V',
            point:
                VoltageDropPoint
                    .batteryPositive,
          ),

          buildVerticalLine(context),

          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  colorScheme.errorContainer,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.warning_amber,
                ),
                SizedBox(height: 4),
                Text(
                  'Плохой контакт',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          buildVerticalLine(context),

          buildCircuitPoint(
            context,
            title: 'B',
            subtitle: loadOn
                ? 'После плохого контакта\n'
                    '${loadVoltage.toStringAsFixed(1)} V'
                : 'После плохого контакта\n'
                    '${sourceVoltage.toStringAsFixed(1)} V',
            point:
                VoltageDropPoint
                    .afterFault,
          ),

          buildVerticalLine(context),

          Icon(
            loadOn
                ? Icons.lightbulb
                : Icons
                    .lightbulb_outline,
            size: 56,
          ),

          const SizedBox(height: 4),

          Text(
            loadOn
                ? 'Лампа горит тускло'
                : 'Лампа выключена',
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          buildVerticalLine(context),

          buildCircuitPoint(
            context,
            title: 'C',
            subtitle: 'Масса\n0 V',
            point:
                VoltageDropPoint.ground,
          ),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: checked
                ? null
                : toggleLoad,
            icon: Icon(
              loadOn
                  ? Icons.toggle_on
                  : Icons.toggle_off,
            ),
            label: Text(
              loadOn
                  ? 'Выключить лампу'
                  : 'Включить лампу',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVerticalLine(
    BuildContext context,
  ) {
    return Container(
      width: 4,
      height: 28,
      color: Theme.of(context)
          .colorScheme
          .outline,
    );
  }

  Widget buildCircuitPoint(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoltageDropPoint point,
  }) {
    final redHere =
        redPoint == point;

    final blackHere =
        blackPoint == point;

    final colorScheme =
        Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  colorScheme.outline,
              width: 4,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              if (redHere)
                Align(
                  alignment:
                      Alignment.topRight,
                  child: Icon(
                    Icons.circle,
                    size: 16,
                    color:
                        colorScheme.error,
                  ),
                ),

              if (blackHere)
                Align(
                  alignment:
                      Alignment.bottomRight,
                  child: Icon(
                    Icons.circle,
                    size: 16,
                    color:
                        colorScheme
                            .onSurface,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: 190,
          child: Text(subtitle),
        ),
      ],
    );
  }

  Widget buildMeter(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final reading = meterReading;

    return Center(
      child: Container(
        width: 330,
        padding:
            const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme
              .surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'V DC',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              height: 90,
              alignment:
                  Alignment.centerRight,
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme
                    .primaryContainer,
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                reading == null
                    ? '---- V'
                    : '${reading.toStringAsFixed(2)} V',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Красный провод: VΩ\n'
              'Чёрный провод: COM',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProbeControls(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Text(
          'Красный щуп',
          style: Theme.of(context)
              .textTheme
              .titleSmall,
        ),

        const SizedBox(height: 8),

        buildPointSelector(
          selected: redPoint,
          onChanged: setRedPoint,
        ),

        const SizedBox(height: 16),

        Text(
          'Чёрный щуп',
          style: Theme.of(context)
              .textTheme
              .titleSmall,
        ),

        const SizedBox(height: 8),

        buildPointSelector(
          selected: blackPoint,
          onChanged: setBlackPoint,
        ),
      ],
    );
  }

  Widget buildPointSelector({
    required VoltageDropPoint? selected,
    required ValueChanged<VoltageDropPoint>
        onChanged,
  }) {
    return SegmentedButton<VoltageDropPoint>(
      segments: const [
        ButtonSegment(
          value:
              VoltageDropPoint
                  .batteryPositive,
          label: Text('A'),
        ),
        ButtonSegment(
          value:
              VoltageDropPoint.afterFault,
          label: Text('B'),
        ),
        ButtonSegment(
          value:
              VoltageDropPoint.ground,
          label: Text('C'),
        ),
      ],
      emptySelectionAllowed: true,
      selected: selected == null
          ? <VoltageDropPoint>{}
          : {selected},
      onSelectionChanged: checked
          ? null
          : (selection) {
              if (selection.isNotEmpty) {
                onChanged(
                  selection.first,
                );
              }
            },
    );
  }

  Widget buildResult(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    if (completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme
              .primaryContainer,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Text(
          '✓ Правильно.\n\n'
          'Красный щуп находится перед '
          'подозрительным соединением, '
          'а чёрный — после него. '
          'При включённой нагрузке '
          'мультиметр показывает '
          '${faultVoltageDrop.toStringAsFixed(1)} V.\n\n'
          'Эти ${faultVoltageDrop.toStringAsFixed(1)} V '
          'теряются именно на плохом '
          'соединении.',
          style: const TextStyle(
            fontWeight:
                FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Container(
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                colorScheme.errorContainer,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Text(
            buildErrorMessage(),
            style: TextStyle(
              color: colorScheme
                  .onErrorContainer,
            ),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(
            Icons.refresh,
          ),
          label: const Text(
            'Попробовать ещё раз',
          ),
        ),
      ],
    );
  }

  String buildErrorMessage() {
    if (!loadOn) {
      return '✗ Нагрузка выключена.\n\n'
          'Падение напряжения на плохом '
          'контакте нужно проверять '
          'при работающей цепи, когда '
          'через соединение течёт ток. '
          'Включи лампу.';
    }

    if (!probesConnected) {
      return '✗ Подключены не оба щупа.';
    }

    if (redPoint ==
        blackPoint) {
      return '✗ Оба щупа находятся '
          'в одной точке. Между одной '
          'и той же точкой разности '
          'потенциалов нет.';
    }

    if (redPoint ==
            VoltageDropPoint.afterFault &&
        blackPoint ==
            VoltageDropPoint
                .batteryPositive) {
      return '✗ Ты нашёл нужный участок, '
          'но поменял щупы местами.\n\n'
          'При таком подключении прибор '
          'покажет отрицательное значение. '
          'Для задания поставь красный '
          'щуп на A, а чёрный на B.';
    }

    if (redPoint ==
            VoltageDropPoint
                .batteryPositive &&
        blackPoint ==
            VoltageDropPoint.ground) {
      return '✗ Сейчас измеряется '
          'напряжение всей цепи '
          'от плюса АКБ до массы.\n\n'
          'Нужно измерить напряжение '
          'непосредственно на '
          'подозрительном соединении: '
          'между A и B.';
    }

    if (redPoint ==
            VoltageDropPoint.afterFault &&
        blackPoint ==
            VoltageDropPoint.ground) {
      return '✗ Сейчас измеряется '
          'напряжение, которое осталось '
          'после плохого контакта.\n\n'
          'Чтобы узнать потерю именно '
          'на контакте, измерь между '
          'A и B.';
    }

    return '✗ Нужно измерить падение '
        'напряжения непосредственно '
        'на плохом контакте при '
        'включённой нагрузке: '
        'красный щуп на A, '
        'чёрный — на B.';
  }
}