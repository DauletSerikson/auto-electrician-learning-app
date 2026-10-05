import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';
import '../../simulation/circuit_simulation.dart';

class CircuitBlock extends StatefulWidget {
  final CircuitLessonBlock block;

  const CircuitBlock({super.key, required this.block});

  @override
  State<CircuitBlock> createState() => _CircuitBlockState();
}

class _CircuitBlockState extends State<CircuitBlock> {
  late bool isClosed;

  bool isParallel = true;

  // Неисправность:
  // true = в цепи лампы 1 имеется обрыв.
  bool lamp1Open = false;

  @override
  void initState() {
    super.initState();

    isClosed = widget.block.initiallyClosed ?? false;
  }

  void toggleCircuit() {
    if (widget.block.interactive != true) {
      return;
    }

    setState(() {
      isClosed = !isClosed;
    });
  }

  void toggleConnection() {
    if (widget.block.interactive != true) {
      return;
    }

    setState(() {
      isParallel = !isParallel;
    });
  }

  void toggleLamp1Fault() {
    if (widget.block.interactive != true) {
      return;
    }

    setState(() {
      lamp1Open = !lamp1Open;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.block.circuitType) {
      case 'simpleLamp':
        return buildSimpleLamp(context);

      case 'twoLamps':
        return buildTwoLamps(context);

      default:
        return Card(
          margin: const EdgeInsets.only(bottom: 24),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Неизвестный тип электрической схемы'),
          ),
        );
    }
  }

  Widget buildSimpleLamp(BuildContext context) {
    final simulation = SimpleLampSimulation(isClosed: isClosed);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildHeader(),

            const SizedBox(height: 20),

            AspectRatio(
              aspectRatio: 1.8,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: SimpleLampCircuitPainter(
                    simulation: simulation,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.outline,
                    textColor: colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: simulation.lampActive
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    simulation.lampActive
                        ? Icons.lightbulb
                        : Icons.lightbulb_outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      simulation.lampActive
                          ? 'Цепь замкнута. '
                                'Лампа включена.'
                          : 'Цепь разомкнута. '
                                'Лампа выключена.',
                    ),
                  ),
                ],
              ),
            ),

            if (widget.block.interactive == true) ...[
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: toggleCircuit,
                icon: Icon(isClosed ? Icons.toggle_off : Icons.toggle_on),
                label: Text(isClosed ? 'Разомкнуть цепь' : 'Замкнуть цепь'),
              ),
            ],

            buildCaption(context),
          ],
        ),
      ),
    );
  }

  Widget buildTwoLamps(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final simulation = TwoLampSimulation(
      topology: isParallel ? LampTopology.parallel : LampTopology.series,
      lamp1Open: lamp1Open,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildHeader(),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    isParallel
                        ? 'ПАРАЛЛЕЛЬНОЕ СОЕДИНЕНИЕ'
                        : 'ПОСЛЕДОВАТЕЛЬНОЕ СОЕДИНЕНИЕ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Источник: ${simulation.sourceVoltage.toStringAsFixed(0)} V',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            AspectRatio(
              aspectRatio: 1.7,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: TwoLampCircuitPainter(
                    simulation: simulation,
                    activeColor: colorScheme.primary,
                    wireColor: colorScheme.outline,
                    textColor: colorScheme.onSurface,
                    errorColor: colorScheme.error,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            buildConnectionInfo(context, simulation),

            if (lamp1Open) ...[
              const SizedBox(height: 12),

              buildFaultExplanation(context),
            ],

            if (widget.block.interactive == true) ...[
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: toggleConnection,
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  isParallel
                      ? 'Показать последовательное'
                      : 'Показать параллельное',
                ),
              ),

              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: toggleLamp1Fault,
                icon: Icon(
                  lamp1Open
                      ? Icons.build_circle_outlined
                      : Icons.warning_amber_outlined,
                ),
                label: Text(
                  lamp1Open
                      ? 'Устранить обрыв лампы 1'
                      : 'Создать обрыв лампы 1',
                ),
              ),
            ],

            buildCaption(context),
          ],
        ),
      ),
    );
  }

  Widget buildConnectionInfo(
    BuildContext context,
    TwoLampSimulation simulation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildLampStatus(
            context,
            number: 1,
            works: simulation.lamp1.isActive,
            value: _widgetIndication(simulation.lamp1.indication),
          ),

          const SizedBox(height: 10),

          buildLampStatus(
            context,
            number: 2,
            works: simulation.lamp2.isActive,
            value: _widgetIndication(simulation.lamp2.indication),
          ),

          const SizedBox(height: 12),

          Text(
            isParallel
                ? 'Каждая лампа находится '
                      'в собственной ветви.'
                : 'Обе лампы находятся '
                      'в одном пути тока.',
          ),
        ],
      ),
    );
  }

  Widget buildLampStatus(
    BuildContext context, {
    required int number,
    required bool works,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          works ? Icons.lightbulb : Icons.lightbulb_outline,
          color: works ? null : colorScheme.error,
        ),

        const SizedBox(width: 8),

        Expanded(child: Text('Лампа $number: $value')),

        Text(
          works ? 'РАБОТАЕТ' : 'НЕ РАБОТАЕТ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: works ? colorScheme.primary : colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget buildFaultExplanation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              isParallel
                  ? 'Обрыв произошёл только '
                        'в ветви лампы 1. '
                        'Ветка лампы 2 остаётся '
                        'замкнутой, поэтому '
                        'лампа 2 продолжает работать.'
                  : 'Обрыв лампы 1 разорвал '
                        'единственный путь тока. '
                        'Поэтому ток не проходит '
                        'ни через лампу 1, '
                        'ни через лампу 2.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    return Row(
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
    );
  }

  Widget buildCaption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        widget.block.caption,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class SimpleLampCircuitPainter extends CustomPainter {
  final SimpleLampSimulation simulation;
  final Color activeColor;
  final Color inactiveColor;
  final Color textColor;

  SimpleLampCircuitPainter({
    required this.simulation,
    required this.activeColor,
    required this.inactiveColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final circuitColor = simulation.lampActive ? activeColor : inactiveColor;

    final wirePaint = Paint()
      ..color = circuitColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final componentPaint = Paint()
      ..color = textColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final lampGlowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final left = size.width * 0.12;
    final right = size.width * 0.88;

    final top = size.height * 0.28;
    final bottom = size.height * 0.72;

    final batteryX = left;
    final switchX = size.width * 0.42;
    final lampX = size.width * 0.72;

    canvas.drawLine(Offset(left, top), Offset(switchX - 35, top), wirePaint);

    canvas.drawLine(
      Offset(switchX + 35, top),
      Offset(lampX - 28, top),
      wirePaint,
    );

    canvas.drawLine(Offset(lampX + 28, top), Offset(right, top), wirePaint);

    canvas.drawLine(Offset(right, top), Offset(right, bottom), wirePaint);

    canvas.drawLine(Offset(right, bottom), Offset(left, bottom), wirePaint);

    canvas.drawLine(
      Offset(batteryX - 20, top + 35),
      Offset(batteryX + 20, top + 35),
      componentPaint,
    );

    canvas.drawLine(
      Offset(batteryX - 12, top + 50),
      Offset(batteryX + 12, top + 50),
      componentPaint,
    );

    canvas.drawLine(
      Offset(batteryX, top),
      Offset(batteryX, top + 35),
      wirePaint,
    );

    canvas.drawLine(
      Offset(batteryX, top + 50),
      Offset(batteryX, bottom),
      wirePaint,
    );

    _drawText(
      canvas,
      textPainter,
      '+',
      Offset(batteryX + 24, top + 24),
      textColor,
      18,
    );

    _drawText(
      canvas,
      textPainter,
      '−',
      Offset(batteryX + 24, top + 45),
      textColor,
      18,
    );

    final switchLeft = Offset(switchX - 35, top);

    final switchRight = Offset(switchX + 35, top);

    canvas.drawCircle(switchLeft, 5, componentPaint);

    canvas.drawCircle(switchRight, 5, componentPaint);

    if (simulation.isClosed) {
      canvas.drawLine(switchLeft, switchRight, componentPaint);
    } else {
      canvas.drawLine(
        switchLeft,
        Offset(switchX + 22, top - 28),
        componentPaint,
      );
    }

    final lampCenter = Offset(lampX, top);

    if (simulation.lampActive) {
      canvas.drawCircle(lampCenter, 38, lampGlowPaint);
    }

    canvas.drawCircle(lampCenter, 27, componentPaint);

    canvas.drawLine(
      Offset(lampX - 17, top - 17),
      Offset(lampX + 17, top + 17),
      componentPaint,
    );

    canvas.drawLine(
      Offset(lampX + 17, top - 17),
      Offset(lampX - 17, top + 17),
      componentPaint,
    );

    _drawText(
      canvas,
      textPainter,
      'АКБ',
      Offset(batteryX - 18, bottom + 10),
      textColor,
      14,
    );

    _drawText(
      canvas,
      textPainter,
      'Выключатель',
      Offset(switchX - 45, top + 28),
      textColor,
      12,
    );

    _drawText(
      canvas,
      textPainter,
      'Лампа',
      Offset(lampX - 22, top + 38),
      textColor,
      12,
    );

    _drawText(
      canvas,
      textPainter,
      'Обратный путь',
      Offset(size.width * 0.48, bottom + 10),
      textColor,
      12,
    );
  }

  void _drawText(
    Canvas canvas,
    TextPainter painter,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    );

    painter.layout();

    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant SimpleLampCircuitPainter oldDelegate) {
    return oldDelegate.simulation.isClosed != simulation.isClosed ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.textColor != textColor;
  }
}

class TwoLampCircuitPainter extends CustomPainter {
  final TwoLampSimulation simulation;

  final Color activeColor;
  final Color wireColor;
  final Color textColor;
  final Color errorColor;

  TwoLampCircuitPainter({
    required this.simulation,
    required this.activeColor,
    required this.wireColor,
    required this.textColor,
    required this.errorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = wireColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final componentPaint = Paint()
      ..color = textColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final faultPaint = Paint()
      ..color = errorColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final lamp1Glow = _lampGlow(simulation.lamp1.activity);
    final lamp2Glow = _lampGlow(simulation.lamp2.activity);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (simulation.topology == LampTopology.parallel) {
      _drawParallel(
        canvas,
        size,
        wirePaint,
        componentPaint,
        faultPaint,
        lamp1Glow,
        lamp2Glow,
        textPainter,
      );
    } else {
      _drawSeries(
        canvas,
        size,
        wirePaint,
        componentPaint,
        faultPaint,
        lamp1Glow,
        lamp2Glow,
        textPainter,
      );
    }
  }

  Paint _lampGlow(LampActivity activity) => Paint()
    ..color = switch (activity) {
      LampActivity.off => Colors.transparent,
      LampActivity.reduced => activeColor.withValues(alpha: 0.10),
      LampActivity.nominal => activeColor.withValues(alpha: 0.28),
    }
    ..style = PaintingStyle.fill;

  Color _indicationColor(LampIndication indication) => switch (indication) {
    VoltageIndication() => textColor,
    OpenCircuitIndication() || NoCurrentIndication() => errorColor,
  };

  void _drawParallel(
    Canvas canvas,
    Size size,
    Paint wirePaint,
    Paint componentPaint,
    Paint faultPaint,
    Paint lamp1Glow,
    Paint lamp2Glow,
    TextPainter textPainter,
  ) {
    final left = size.width * 0.12;

    final top = size.height * 0.25;
    final bottom = size.height * 0.75;

    final branchStart = size.width * 0.34;

    final branchEnd = size.width * 0.76;

    final lampX = (branchStart + branchEnd) / 2;

    final upperY = size.height * 0.36;

    final lowerY = size.height * 0.64;

    _drawBattery(
      canvas,
      left,
      top,
      bottom,
      wirePaint,
      componentPaint,
      textPainter,
    );

    canvas.drawLine(Offset(left, top), Offset(branchStart, top), wirePaint);

    canvas.drawLine(
      Offset(branchStart, top),
      Offset(branchStart, lowerY),
      wirePaint,
    );

    // Верхняя ветвь — лампа 1.
    canvas.drawLine(
      Offset(branchStart, upperY),
      Offset(lampX - 25, upperY),
      wirePaint,
    );

    canvas.drawLine(
      Offset(lampX + 25, upperY),
      Offset(branchEnd, upperY),
      wirePaint,
    );

    // Нижняя ветвь — лампа 2.
    canvas.drawLine(
      Offset(branchStart, lowerY),
      Offset(lampX - 25, lowerY),
      wirePaint,
    );

    canvas.drawLine(
      Offset(lampX + 25, lowerY),
      Offset(branchEnd, lowerY),
      wirePaint,
    );

    canvas.drawLine(
      Offset(branchEnd, upperY),
      Offset(branchEnd, bottom),
      wirePaint,
    );

    canvas.drawLine(Offset(branchEnd, bottom), Offset(left, bottom), wirePaint);

    _drawLamp(canvas, Offset(lampX, upperY), componentPaint, lamp1Glow);

    _drawLamp(canvas, Offset(lampX, lowerY), componentPaint, lamp2Glow);

    if (simulation.lamp1Open) {
      _drawFault(canvas, Offset(lampX, upperY), faultPaint);
    }

    _drawText(
      canvas,
      textPainter,
      _canvasIndication(simulation.lamp1.indication),
      Offset(lampX - 20, upperY - 48),
      _indicationColor(simulation.lamp1.indication),
      12,
    );

    _drawText(
      canvas,
      textPainter,
      _canvasIndication(simulation.lamp2.indication),
      Offset(lampX - 14, lowerY + 30),
      textColor,
      12,
    );

    _drawText(
      canvas,
      textPainter,
      'Лампа 1',
      Offset(lampX + 35, upperY - 8),
      textColor,
      11,
    );

    _drawText(
      canvas,
      textPainter,
      'Лампа 2',
      Offset(lampX + 35, lowerY - 8),
      textColor,
      11,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    Paint wirePaint,
    Paint componentPaint,
    Paint faultPaint,
    Paint lamp1Glow,
    Paint lamp2Glow,
    TextPainter textPainter,
  ) {
    final left = size.width * 0.12;
    final right = size.width * 0.88;

    final top = size.height * 0.32;
    final bottom = size.height * 0.72;

    final lamp1X = size.width * 0.43;

    final lamp2X = size.width * 0.69;

    _drawBattery(
      canvas,
      left,
      top,
      bottom,
      wirePaint,
      componentPaint,
      textPainter,
    );

    canvas.drawLine(Offset(left, top), Offset(lamp1X - 25, top), wirePaint);

    canvas.drawLine(
      Offset(lamp1X + 25, top),
      Offset(lamp2X - 25, top),
      wirePaint,
    );

    canvas.drawLine(Offset(lamp2X + 25, top), Offset(right, top), wirePaint);

    canvas.drawLine(Offset(right, top), Offset(right, bottom), wirePaint);

    canvas.drawLine(Offset(right, bottom), Offset(left, bottom), wirePaint);

    _drawLamp(canvas, Offset(lamp1X, top), componentPaint, lamp1Glow);

    _drawLamp(canvas, Offset(lamp2X, top), componentPaint, lamp2Glow);

    if (simulation.lamp1Open) {
      _drawFault(canvas, Offset(lamp1X, top), faultPaint);
    }

    _drawText(
      canvas,
      textPainter,
      _canvasIndication(simulation.lamp1.indication),
      Offset(lamp1X - 20, top - 48),
      _indicationColor(simulation.lamp1.indication),
      12,
    );

    _drawText(
      canvas,
      textPainter,
      _canvasIndication(simulation.lamp2.indication),
      Offset(lamp2X - 28, top - 48),
      _indicationColor(simulation.lamp2.indication),
      12,
    );

    _drawText(
      canvas,
      textPainter,
      'Лампа 1',
      Offset(lamp1X - 26, top + 35),
      textColor,
      11,
    );

    _drawText(
      canvas,
      textPainter,
      'Лампа 2',
      Offset(lamp2X - 26, top + 35),
      textColor,
      11,
    );
  }

  void _drawBattery(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Paint wirePaint,
    Paint componentPaint,
    TextPainter textPainter,
  ) {
    final plate1 = top + 35;
    final plate2 = top + 50;

    canvas.drawLine(Offset(x, top), Offset(x, plate1), wirePaint);

    canvas.drawLine(
      Offset(x - 20, plate1),
      Offset(x + 20, plate1),
      componentPaint,
    );

    canvas.drawLine(
      Offset(x - 12, plate2),
      Offset(x + 12, plate2),
      componentPaint,
    );

    canvas.drawLine(Offset(x, plate2), Offset(x, bottom), wirePaint);

    _drawText(
      canvas,
      textPainter,
      '+',
      Offset(x + 24, plate1 - 10),
      textColor,
      16,
    );

    _drawText(
      canvas,
      textPainter,
      '−',
      Offset(x + 24, plate2 - 7),
      textColor,
      16,
    );

    _drawText(
      canvas,
      textPainter,
      '${simulation.sourceVoltage.toStringAsFixed(0)} V',
      Offset(x - 15, bottom + 8),
      textColor,
      12,
    );
  }

  void _drawLamp(
    Canvas canvas,
    Offset center,
    Paint componentPaint,
    Paint glowPaint,
  ) {
    canvas.drawCircle(center, 34, glowPaint);

    canvas.drawCircle(center, 24, componentPaint);

    canvas.drawLine(
      Offset(center.dx - 15, center.dy - 15),
      Offset(center.dx + 15, center.dy + 15),
      componentPaint,
    );

    canvas.drawLine(
      Offset(center.dx + 15, center.dy - 15),
      Offset(center.dx - 15, center.dy + 15),
      componentPaint,
    );
  }

  void _drawFault(Canvas canvas, Offset center, Paint faultPaint) {
    canvas.drawLine(
      Offset(center.dx - 32, center.dy - 32),
      Offset(center.dx + 32, center.dy + 32),
      faultPaint,
    );

    canvas.drawLine(
      Offset(center.dx + 32, center.dy - 32),
      Offset(center.dx - 32, center.dy + 32),
      faultPaint,
    );
  }

  void _drawText(
    Canvas canvas,
    TextPainter painter,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    );

    painter.layout();

    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant TwoLampCircuitPainter oldDelegate) {
    return oldDelegate.simulation.topology != simulation.topology ||
        oldDelegate.simulation.lamp1Open != simulation.lamp1Open ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.wireColor != wireColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.errorColor != errorColor;
  }
}

String _voltageLabel(VoltageIndication indication) =>
    '${indication.isApproximate ? '≈ ' : ''}${indication.volts.toStringAsFixed(0)} V';

String _widgetIndication(LampIndication indication) => switch (indication) {
  VoltageIndication() => _voltageLabel(indication),
  OpenCircuitIndication() => 'обрыв',
  NoCurrentIndication() => 'ток не проходит',
};

String _canvasIndication(LampIndication indication) => switch (indication) {
  VoltageIndication() => _voltageLabel(indication),
  OpenCircuitIndication() => 'ОБРЫВ',
  NoCurrentIndication() => 'НЕТ ТОКА',
};
