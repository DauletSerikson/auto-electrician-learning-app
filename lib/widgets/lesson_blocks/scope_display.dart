import 'package:flutter/material.dart';

import '../../simulation/oscilloscope_simulation.dart';

/// Presentation only; all voltages, time coordinates and trigger events are domain data.
class ScopeDisplay extends StatelessWidget {
  final ScopeCapture capture;

  const ScopeDisplay({super.key, required this.capture});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.35,
    child: CustomPaint(
      key: const ValueKey('scope_plot'),
      painter: ScopePainter(capture, MediaQuery.textScalerOf(context)),
    ),
  );
}

class ScopePainter extends CustomPainter {
  final ScopeCapture capture;
  final TextScaler textScaler;

  ScopePainter(this.capture, this.textScaler);

  static const background = Color(0xff071923);
  static const grid = Color(0xff34515c);
  static const trace = Color(0xff68eeff);
  static const trigger = Color(0xffffd166);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final rect = Rect.fromLTRB(46, 20, size.width - 10, size.height - 36);
    final settings = capture.settings;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var x = 0; x <= 10; x++) {
      final dx = rect.left + rect.width * x / 10;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), gridPaint);
    }
    for (var y = 0; y <= 8; y++) {
      final dy = rect.top + rect.height * y / 8;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }
    double yFor(double voltage) =>
        rect.top + rect.height * settings.yFraction(voltage);
    final zero = yFor(0);
    if (zero >= rect.top && zero <= rect.bottom) {
      canvas.drawLine(
        Offset(rect.left, zero),
        Offset(rect.right, zero),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5,
      );
      _label(canvas, '0', Offset(4, zero - 8));
    }
    final level = yFor(settings.triggerLevel);
    if (level >= rect.top && level <= rect.bottom) {
      for (double x = rect.left; x < rect.right; x += 10) {
        canvas.drawLine(
          Offset(x, level),
          Offset((x + 5).clamp(rect.left, rect.right), level),
          Paint()..color = trigger,
        );
      }
      _label(canvas, 'L', Offset(rect.right - 13, level - 18), color: trigger);
    }
    final triggerSeconds = capture.triggerSeconds;
    if (triggerSeconds != null) {
      final x =
          rect.left +
          rect.width * settings.xFraction(triggerSeconds, capture.startSeconds);
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        Paint()
          ..color = trigger
          ..strokeWidth = 1,
      );
      _label(canvas, 'T', Offset(x + 2, rect.top), color: trigger);
    }
    if (capture.points.isNotEmpty) {
      final path = Path();
      for (var i = 0; i < capture.points.length; i++) {
        final point = capture.points[i];
        final x =
            rect.left +
            rect.width *
                settings.xFraction(point.seconds, capture.startSeconds);
        final y = yFor(point.voltage);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawPath(
        path,
        Paint()
          ..color = trace
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
    _label(canvas, 'V', const Offset(4, 1));
    _label(canvas, _number(settings.topVoltage), Offset(4, rect.top));
    _label(
      canvas,
      _number(settings.bottomVoltage),
      Offset(4, rect.bottom - 14),
    );
    _label(
      canvas,
      _number(capture.startSeconds * 1000),
      Offset(rect.left, rect.bottom + 4),
    );
    _label(
      canvas,
      '${_number((capture.startSeconds + settings.windowSeconds) * 1000)} ms',
      Offset(rect.right, rect.bottom + 4),
      alignRight: true,
    );
  }

  String _number(double number) => number.toStringAsFixed(1);

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    Color color = Colors.white,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10, fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    painter.paint(
      canvas,
      alignRight ? offset - Offset(painter.width, 0) : offset,
    );
  }

  @override
  bool shouldRepaint(covariant ScopePainter oldDelegate) =>
      oldDelegate.capture != capture || oldDelegate.textScaler != textScaler;
}
