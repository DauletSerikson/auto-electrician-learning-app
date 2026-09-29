import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';

enum MultimeterMode {
  off,
  dcVoltage,
  acVoltage,
  resistance,
  current,
}

enum RedProbePort {
  voltageResistance,
  current,
}

class MultimeterBlock extends StatefulWidget {
  final LessonBlock block;

  const MultimeterBlock({
    super.key,
    required this.block,
  });

  @override
  State<MultimeterBlock> createState() =>
      _MultimeterBlockState();
}

class _MultimeterBlockState
    extends State<MultimeterBlock> {
  MultimeterMode selectedMode =
      MultimeterMode.off;

  RedProbePort redProbePort =
      RedProbePort.voltageResistance;

  @override
  void initState() {
    super.initState();

    selectedMode = modeFromString(
      widget.block.multimeterMode,
    );
  }

  MultimeterMode modeFromString(
    String? value,
  ) {
    switch (value) {
      case 'dcVoltage':
        return MultimeterMode.dcVoltage;

      case 'acVoltage':
        return MultimeterMode.acVoltage;

      case 'resistance':
        return MultimeterMode.resistance;

      case 'current':
        return MultimeterMode.current;

      default:
        return MultimeterMode.off;
    }
  }

  String get displayText {
    switch (selectedMode) {
      case MultimeterMode.off:
        return '';

      case MultimeterMode.dcVoltage:
        return '0.00';

      case MultimeterMode.acVoltage:
        return '0.00';

      case MultimeterMode.resistance:
        return 'OL';

      case MultimeterMode.current:
        return '0.00';
    }
  }

  String get displayUnit {
    switch (selectedMode) {
      case MultimeterMode.off:
        return 'OFF';

      case MultimeterMode.dcVoltage:
        return 'V DC';

      case MultimeterMode.acVoltage:
        return 'V AC';

      case MultimeterMode.resistance:
        return 'Ω';

      case MultimeterMode.current:
        return 'A';
    }
  }

  String get modeTitle {
    switch (selectedMode) {
      case MultimeterMode.off:
        return 'Мультиметр выключен';

      case MultimeterMode.dcVoltage:
        return 'Постоянное напряжение';

      case MultimeterMode.acVoltage:
        return 'Переменное напряжение';

      case MultimeterMode.resistance:
        return 'Сопротивление';

      case MultimeterMode.current:
        return 'Сила тока';
    }
  }

  String get modeDescription {
    switch (selectedMode) {
      case MultimeterMode.off:
        return 'В положении OFF прибор '
            'выключен.';

      case MultimeterMode.dcVoltage:
        return 'Режим V DC используется '
            'для измерения постоянного '
            'напряжения. Для обычного '
            'измерения напряжения красный '
            'щуп должен находиться '
            'в гнезде VΩ.';

      case MultimeterMode.acVoltage:
        return 'Режим V AC используется '
            'для измерения переменного '
            'напряжения. Красный щуп '
            'обычно подключается '
            'к гнезду VΩ.';

      case MultimeterMode.resistance:
        return 'Режим Ω используется '
            'для измерения сопротивления. '
            'Красный щуп подключается '
            'к гнезду VΩ. Измеряемая '
            'цепь при такой проверке '
            'должна быть обесточена.';

      case MultimeterMode.current:
        return 'Для измерения силы тока '
            'используется токовый вход. '
            'На нашем учебном приборе '
            'красный щуп нужно переставить '
            'из VΩ в A.';
    }
  }

  bool get redProbeCorrect {
    switch (selectedMode) {
      case MultimeterMode.off:
        return true;

      case MultimeterMode.dcVoltage:
      case MultimeterMode.acVoltage:
      case MultimeterMode.resistance:
        return redProbePort ==
            RedProbePort.voltageResistance;

      case MultimeterMode.current:
        return redProbePort ==
            RedProbePort.current;
    }
  }

  bool get showProbeStatus {
    return selectedMode !=
        MultimeterMode.off;
  }

  bool get isCurrentMode {
    return selectedMode ==
        MultimeterMode.current;
  }

  void selectMode(
    MultimeterMode mode,
  ) {
    if (widget.block.interactive != true) {
      return;
    }

    setState(() {
      selectedMode = mode;
    });
  }

  void selectRedProbePort(
    RedProbePort port,
  ) {
    if (widget.block.interactive != true) {
      return;
    }

    setState(() {
      redProbePort = port;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(
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
                  Icons.speed_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.block.title ??
                        'Виртуальный мультиметр',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Center(
              child: Container(
                width: 350,
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(28),
                  border: Border.all(
                    color:
                        colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    buildDisplay(context),

                    const SizedBox(height: 24),

                    buildSelector(context),

                    const SizedBox(height: 28),

                    buildPorts(context),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            buildModeInformation(
              context,
            ),

            if (showProbeStatus) ...[
              const SizedBox(height: 12),

              buildProbeStatus(
                context,
              ),
            ],

            if (widget.block.caption !=
                null) ...[
              const SizedBox(height: 12),

              Text(
                widget.block.caption!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildDisplay(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      height: 90,
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: selectedMode ==
                MultimeterMode.off
            ? colorScheme.surface
            : colorScheme
                .primaryContainer,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(
            displayText.isEmpty
                ? '────'
                : displayText,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                  fontFeatures: const [
                    FontFeature
                        .tabularFigures(),
                  ],
                ),
          ),

          Text(
            displayUnit,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSelector(
    BuildContext context,
  ) {
    return Column(
      children: [
        const Text(
          'Переключатель режимов',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          alignment:
              WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            buildModeButton(
              MultimeterMode.off,
              'OFF',
            ),

            buildModeButton(
              MultimeterMode.dcVoltage,
              'V DC',
            ),

            buildModeButton(
              MultimeterMode.acVoltage,
              'V AC',
            ),

            buildModeButton(
              MultimeterMode.resistance,
              'Ω',
            ),

            buildModeButton(
              MultimeterMode.current,
              'A',
            ),
          ],
        ),
      ],
    );
  }

  Widget buildModeButton(
    MultimeterMode mode,
    String label,
  ) {
    final selected =
        selectedMode == mode;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        selectMode(mode);
      },
    );
  }

  Widget buildPorts(
    BuildContext context,
  ) {
    return Column(
      children: [
        const Text(
          'Гнёзда щупов',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceEvenly,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            buildFixedComPort(
              context,
            ),

            buildSelectablePort(
              context,
              label: 'VΩ',
              subtitle:
                  'напряжение\nсопротивление',
              port: RedProbePort
                  .voltageResistance,
            ),

            buildSelectablePort(
              context,
              label: 'A',
              subtitle: 'ток',
              port:
                  RedProbePort.current,
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          'Нажми на VΩ или A, '
          'чтобы переставить красный щуп.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }

  Widget buildFixedComPort(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme
                  .onSurface,
              border: Border.all(
                color:
                    colorScheme.outline,
                width: 4,
              ),
            ),
            child: Icon(
              Icons.cable,
              size: 20,
              color:
                  colorScheme.surface,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'COM',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            'чёрный щуп',
            textAlign:
                TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }

  Widget buildSelectablePort(
    BuildContext context, {
    required String label,
    required String subtitle,
    required RedProbePort port,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final selected =
        redProbePort == port;

    return SizedBox(
      width: 88,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap:
            widget.block.interactive ==
                    true
                ? () {
                    selectRedProbePort(
                      port,
                    );
                  }
                : null,
        child: Padding(
          padding:
              const EdgeInsets.all(6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colorScheme.error
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? colorScheme.error
                        : colorScheme
                            .outline,
                    width: 4,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.cable,
                        size: 20,
                        color: colorScheme
                            .onError,
                      )
                    : null,
              ),

              const SizedBox(height: 8),

              Text(
                label,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                selected
                    ? 'красный щуп'
                    : subtitle,
                textAlign:
                    TextAlign.center,
                style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildModeInformation(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentMode
            ? colorScheme
                .errorContainer
            : colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            modeTitle,
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              color: isCurrentMode
                  ? colorScheme
                      .onErrorContainer
                  : null,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            modeDescription,
            style: TextStyle(
              color: isCurrentMode
                  ? colorScheme
                      .onErrorContainer
                  : null,
            ),
          ),

          if (isCurrentMode) ...[
            const SizedBox(height: 12),

            Text(
              '⚠ Даже при правильно '
              'переставленном красном щупе '
              'мультиметр в режиме A '
              'нельзя подключать напрямую '
              'параллельно аккумулятору.',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: colorScheme
                    .onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildProbeStatus(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    if (redProbeCorrect) {
      return Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme
              .primaryContainer,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                correctProbeMessage,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            colorScheme.errorContainer,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            color:
                colorScheme.onErrorContainer,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              incorrectProbeMessage,
              style: TextStyle(
                color: colorScheme
                    .onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get correctProbeMessage {
    switch (selectedMode) {
      case MultimeterMode.off:
        return '';

      case MultimeterMode.dcVoltage:
        return '✓ Для измерения '
            'постоянного напряжения '
            'красный щуп находится '
            'в правильном гнезде VΩ.';

      case MultimeterMode.acVoltage:
        return '✓ Для измерения '
            'переменного напряжения '
            'красный щуп находится '
            'в правильном гнезде VΩ.';

      case MultimeterMode.resistance:
        return '✓ Для измерения '
            'сопротивления красный '
            'щуп находится '
            'в правильном гнезде VΩ.';

      case MultimeterMode.current:
        return '✓ Для учебного режима '
            'измерения тока красный '
            'щуп переставлен '
            'в токовое гнездо A.';
    }
  }

  String get incorrectProbeMessage {
    switch (selectedMode) {
      case MultimeterMode.off:
        return '';

      case MultimeterMode.dcVoltage:
        return 'Красный щуп находится '
            'в токовом гнезде A. '
            'Для измерения напряжения '
            'переставь его в VΩ.';

      case MultimeterMode.acVoltage:
        return 'Красный щуп находится '
            'в токовом гнезде A. '
            'Для измерения напряжения '
            'переставь его в VΩ.';

      case MultimeterMode.resistance:
        return 'Красный щуп находится '
            'в токовом гнезде A. '
            'Для измерения сопротивления '
            'переставь его в VΩ.';

      case MultimeterMode.current:
        return 'Красный щуп находится '
            'в VΩ. Для выбранного '
            'учебного режима измерения '
            'тока переставь его '
            'в гнездо A.';
    }
  }
}