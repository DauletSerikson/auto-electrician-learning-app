import 'dart:math' as math;

enum ScopeEdge { rising, falling }

/// An ideal voltage source relative to the model's reference N = 0 V.
sealed class ScopeSignal {
  const ScopeSignal();

  double get minimum;
  double get maximum;
  double voltageAt(double seconds);
  List<double> crossings(double level, ScopeEdge edge, double duration);
  List<ScopeTransition> transitions(double duration) => const [];
}

sealed class PeriodicScopeSignal extends ScopeSignal {
  final double frequencyHz;

  PeriodicScopeSignal(this.frequencyHz) {
    if (!frequencyHz.isFinite || frequencyHz < 1 || frequencyHz > 1000) {
      throw ArgumentError.value(
        frequencyHz,
        'frequencyHz',
        'Expected 1…1000 Hz',
      );
    }
  }

  double get periodSeconds => 1 / frequencyHz;
}

final class ConstantScopeSignal extends ScopeSignal {
  final double voltage;

  ConstantScopeSignal(this.voltage) {
    _voltage(voltage);
  }

  @override
  double get minimum => voltage;
  @override
  double get maximum => voltage;
  @override
  double voltageAt(double seconds) => voltage;
  @override
  List<double> crossings(double level, ScopeEdge edge, double duration) => [];
}

final class SineScopeSignal extends PeriodicScopeSignal {
  final double amplitude;
  final double offset;

  SineScopeSignal({
    required this.amplitude,
    required this.offset,
    required double frequencyHz,
  }) : super(frequencyHz) {
    if (!amplitude.isFinite || amplitude <= 0) {
      throw ArgumentError.value(amplitude, 'amplitude');
    }
    _voltage(minimum);
    _voltage(maximum);
  }

  @override
  double get minimum => offset - amplitude;
  @override
  double get maximum => offset + amplitude;
  @override
  double voltageAt(double seconds) =>
      offset + amplitude * math.sin(2 * math.pi * frequencyHz * seconds);

  @override
  List<double> crossings(double level, ScopeEdge edge, double duration) {
    // A tangent at an extremum is not a directional crossing.
    if (level <= minimum || level >= maximum || !level.isFinite) return [];
    final angle = math.asin((level - offset) / amplitude);
    final phase = edge == ScopeEdge.rising ? angle : math.pi - angle;
    final first = phase / (2 * math.pi) * periodSeconds;
    return [
      for (var k = -1; k <= (duration / periodSeconds).ceil(); k++)
        if (first + k * periodSeconds >= 0 &&
            first + k * periodSeconds <= duration)
          first + k * periodSeconds,
    ];
  }
}

final class PulseScopeSignal extends PeriodicScopeSignal {
  final double low;
  final double high;
  final double duty;

  PulseScopeSignal({
    required this.low,
    required this.high,
    required this.duty,
    required double frequencyHz,
  }) : super(frequencyHz) {
    _voltage(low);
    _voltage(high);
    if (high <= low || !duty.isFinite || duty <= 0 || duty >= 1) {
      throw ArgumentError('Pulse requires high > low and 0 < duty < 1');
    }
  }

  double get highSeconds => periodSeconds * duty;
  double get averageVoltage => low + (high - low) * duty;
  @override
  double get minimum => low;
  @override
  double get maximum => high;
  @override
  double voltageAt(double seconds) {
    var cycle = (seconds / periodSeconds).floor();
    // Compare against the same exact event times used by transitions().
    // Division/subtraction of phase fractions can move a falling edge high.
    if (seconds >= (cycle + 1) * periodSeconds) cycle++;
    if (seconds < cycle * periodSeconds) cycle--;
    return seconds < cycle * periodSeconds + highSeconds ? high : low;
  }

  @override
  List<ScopeTransition> transitions(double duration) => [
    for (var k = 0; k <= (duration / periodSeconds).ceil(); k++) ...[
      // No rising event at t=0: there is no recorded preceding low level.
      if (k > 0 && k * periodSeconds <= duration)
        ScopeTransition(k * periodSeconds, low, high),
      if (k * periodSeconds + highSeconds <= duration)
        ScopeTransition(k * periodSeconds + highSeconds, high, low),
    ],
  ];

  @override
  List<double> crossings(double level, ScopeEdge edge, double duration) =>
      _pulseCrossings(transitions(duration), level, edge);
}

/// Exactly one whole high pulse is suppressed. The record is not periodic.
final class MissingPulseScopeSignal extends ScopeSignal {
  final PulseScopeSignal carrier;
  final int missingIndex;

  MissingPulseScopeSignal({required this.carrier, required this.missingIndex}) {
    if (missingIndex < 1 || missingIndex > 100) {
      throw ArgumentError.value(missingIndex, 'missingIndex');
    }
  }

  double get eventStart => missingIndex * carrier.periodSeconds;
  double get eventEnd => eventStart + carrier.highSeconds;
  @override
  double get minimum => carrier.low;
  @override
  double get maximum => carrier.high;
  @override
  double voltageAt(double seconds) =>
      seconds >= eventStart && seconds < eventEnd
      ? carrier.low
      : carrier.voltageAt(seconds);

  @override
  List<ScopeTransition> transitions(double duration) => carrier
      .transitions(duration)
      .where(
        (event) =>
            (event.seconds - eventStart).abs() > 1e-12 &&
            (event.seconds - eventEnd).abs() > 1e-12,
      )
      .toList();

  @override
  List<double> crossings(double level, ScopeEdge edge, double duration) =>
      _pulseCrossings(transitions(duration), level, edge);
}

final class ScopeTransition {
  final double seconds;
  final double before;
  final double after;

  const ScopeTransition(this.seconds, this.before, this.after);
}

List<double> _pulseCrossings(
  List<ScopeTransition> events,
  double level,
  ScopeEdge edge,
) => [
  for (final event in events)
    if (switch (edge) {
      ScopeEdge.rising => event.before < level && event.after >= level,
      ScopeEdge.falling => event.before > level && event.after <= level,
    })
      event.seconds,
];

void _voltage(double value) {
  if (!value.isFinite || value < -100 || value > 100) {
    throw ArgumentError.value(value, 'voltage', 'Expected −100…100 V');
  }
}

enum ScopeScenario {
  constant,
  sine,
  square,
  pwm30,
  pwm60,
  missingPulse;

  ScopeSignal get signal => switch (this) {
    constant => ConstantScopeSignal(2.5),
    sine => SineScopeSignal(amplitude: 4, offset: 0, frequencyHz: 100),
    square => PulseScopeSignal(low: 0, high: 5, duty: 0.5, frequencyHz: 100),
    pwm30 => PulseScopeSignal(low: 0, high: 5, duty: 0.3, frequencyHz: 100),
    pwm60 => PulseScopeSignal(low: 0, high: 5, duty: 0.6, frequencyHz: 100),
    missingPulse => MissingPulseScopeSignal(
      carrier: PulseScopeSignal(low: 0, high: 5, duty: 0.3, frequencyHz: 100),
      missingIndex: 2,
    ),
  };
}
