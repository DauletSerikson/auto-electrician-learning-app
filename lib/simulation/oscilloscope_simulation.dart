import 'scope_signal.dart';

enum ScopeTriggerMode { normal, auto, single }

enum ScopeCaptureStatus { triggered, freeRunning, waiting, armed }

enum ScopeExercise { voltageScale, timeScale, trigger }

final class ScopeSettings {
  static const voltageScales = [0.5, 1.0, 2.0, 5.0];
  static const timeScalesMs = [1.0, 2.0, 4.0, 10.0];
  static const centers = [-2.0, 0.0, 2.5, 5.0];
  static const triggerLevels = [-2.0, 0.0, 2.5, 6.0];

  final double voltsPerDiv;
  final double millisecondsPerDiv;
  final double centerVoltage;
  final double triggerLevel;
  final ScopeEdge edge;
  final ScopeTriggerMode mode;

  ScopeSettings({
    this.voltsPerDiv = 1,
    this.millisecondsPerDiv = 4,
    this.centerVoltage = 2.5,
    this.triggerLevel = 2.5,
    this.edge = ScopeEdge.rising,
    this.mode = ScopeTriggerMode.normal,
  }) {
    if (!voltageScales.contains(voltsPerDiv) ||
        !timeScalesMs.contains(millisecondsPerDiv) ||
        !centers.contains(centerVoltage) ||
        !triggerLevels.contains(triggerLevel)) {
      throw ArgumentError('Unsupported scope settings');
    }
  }

  double get windowSeconds => millisecondsPerDiv / 100;
  double get bottomVoltage => centerVoltage - 4 * voltsPerDiv;
  double get topVoltage => centerVoltage + 4 * voltsPerDiv;
  double yFraction(double voltage) =>
      0.5 - (voltage - centerVoltage) / (8 * voltsPerDiv);
  double xFraction(double time, double start) => (time - start) / windowSeconds;

  ScopeSettings copyWith({
    double? voltsPerDiv,
    double? millisecondsPerDiv,
    double? centerVoltage,
    double? triggerLevel,
    ScopeEdge? edge,
    ScopeTriggerMode? mode,
  }) => ScopeSettings(
    voltsPerDiv: voltsPerDiv ?? this.voltsPerDiv,
    millisecondsPerDiv: millisecondsPerDiv ?? this.millisecondsPerDiv,
    centerVoltage: centerVoltage ?? this.centerVoltage,
    triggerLevel: triggerLevel ?? this.triggerLevel,
    edge: edge ?? this.edge,
    mode: mode ?? this.mode,
  );
}

final class ScopePoint {
  final double seconds;
  final double voltage;

  const ScopePoint(this.seconds, this.voltage);
}

/// Immutable record. No retained trace is silently relabelled after a setting change.
final class ScopeCapture {
  final ScopeCaptureStatus status;
  final ScopeSettings settings;
  final double startSeconds;
  final double? triggerSeconds;
  final List<ScopePoint> points;

  ScopeCapture({
    required this.status,
    required this.settings,
    this.startSeconds = 0,
    this.triggerSeconds,
    List<ScopePoint> points = const [],
  }) : points = List.unmodifiable(points);

  bool get clipped => points.any(
    (point) =>
        point.voltage < settings.bottomVoltage ||
        point.voltage > settings.topVoltage,
  );
}

/// Finite deterministic record [0, 200 ms], not a live acquisition engine.
final class OscilloscopeSimulation {
  static const recordSeconds = 0.2;
  static const sampleSeconds = 0.00001;

  const OscilloscopeSimulation();

  ScopeCapture capture(
    ScopeSignal signal,
    ScopeSettings settings, {
    bool armSingle = false,
  }) {
    if (settings.mode == ScopeTriggerMode.single && !armSingle) {
      return ScopeCapture(status: ScopeCaptureStatus.armed, settings: settings);
    }
    final window = settings.windowSeconds;
    double? trigger;
    for (final time in signal.crossings(
      settings.triggerLevel,
      settings.edge,
      recordSeconds,
    )) {
      // Require the complete 20% pre-trigger / 80% post-trigger window.
      if (time >= window * 0.2 - 1e-12 &&
          time + window * 0.8 <= recordSeconds + 1e-12) {
        trigger = time;
        break;
      }
    }
    if (trigger == null && settings.mode != ScopeTriggerMode.auto) {
      return ScopeCapture(
        status: settings.mode == ScopeTriggerMode.single
            ? ScopeCaptureStatus.armed
            : ScopeCaptureStatus.waiting,
        settings: settings,
      );
    }
    final start = trigger == null
        ? 0.0
        : (trigger - window * 0.2).clamp(0.0, recordSeconds - window);
    return ScopeCapture(
      status: trigger == null
          ? ScopeCaptureStatus.freeRunning
          : ScopeCaptureStatus.triggered,
      settings: settings,
      startSeconds: start,
      triggerSeconds: trigger,
      points: _trace(signal, start, start + window),
    );
  }

  List<ScopePoint> _trace(ScopeSignal signal, double start, double end) {
    // Preserve both sides at the exact same x-coordinate of every step.
    // Trigger detection never depends on drawing samples or pixel resolution.
    final events = signal
        .transitions(recordSeconds)
        .where((e) => e.seconds >= start && e.seconds <= end)
        .toList();
    final points = <ScopePoint>[];
    var eventIndex = 0;
    final count = ((end - start) / sampleSeconds).ceil();
    for (var i = 0; i <= count; i++) {
      final time = i == count ? end : start + i * sampleSeconds;
      var atEvent = false;
      while (eventIndex < events.length &&
          events[eventIndex].seconds <= time + 1e-12) {
        final event = events[eventIndex++];
        points.add(ScopePoint(event.seconds, event.before));
        points.add(ScopePoint(event.seconds, event.after));
        atEvent = (event.seconds - time).abs() < 1e-12;
      }
      if (!atEvent) points.add(ScopePoint(time, signal.voltageAt(time)));
    }
    return points;
  }

  bool evaluate({
    required ScopeExercise exercise,
    required ScopeScenario target,
    required ScopeScenario selected,
    required ScopeCapture capture,
  }) {
    if (selected != target || capture.points.isEmpty) return false;
    final signal = selected.signal;
    final settings = capture.settings;
    final visibleRising = signal
        .crossings(
          (signal.minimum + signal.maximum) / 2,
          ScopeEdge.rising,
          recordSeconds,
        )
        .where(
          (time) =>
              time >= capture.startSeconds - 1e-12 &&
              time <= capture.startSeconds + settings.windowSeconds + 1e-12,
        )
        .length;
    final completePeriods = visibleRising - 1;
    return switch (exercise) {
      ScopeExercise.voltageScale =>
        !capture.clipped &&
            (signal.maximum - signal.minimum) / (8 * settings.voltsPerDiv) >=
                0.5 &&
            (signal.maximum - signal.minimum) / (8 * settings.voltsPerDiv) <=
                0.9,
      ScopeExercise.timeScale =>
        signal is PeriodicScopeSignal &&
            completePeriods >= 2 &&
            completePeriods <= 5 &&
            !capture.clipped,
      ScopeExercise.trigger =>
        capture.status == ScopeCaptureStatus.triggered &&
            settings.mode == ScopeTriggerMode.normal &&
            settings.edge == ScopeEdge.rising &&
            !capture.clipped,
    };
  }
}
