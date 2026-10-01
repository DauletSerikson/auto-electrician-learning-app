enum LampTopology { parallel, series }

/// Qualitative electrical operation, independent of how glow is rendered.
enum LampActivity {
  off,
  reduced,
  nominal;

  bool get isActive => this != off;
}

/// An educational indication, not necessarily a voltmeter reading.
sealed class LampIndication {
  const LampIndication();
}

final class VoltageIndication extends LampIndication {
  final double volts;
  final bool isApproximate;

  const VoltageIndication(this.volts, {this.isApproximate = false});
}

final class OpenCircuitIndication extends LampIndication {
  const OpenCircuitIndication();
}

final class NoCurrentIndication extends LampIndication {
  const NoCurrentIndication();
}

final class LampResult {
  final LampActivity activity;
  final LampIndication indication;

  const LampResult._({required this.activity, required this.indication});

  bool get isActive => activity.isActive;
}

final class SimpleLampSimulation {
  final bool isClosed;

  const SimpleLampSimulation({required this.isClosed});

  bool get lampActive => isClosed;
}

/// Fixed 12 V source and two identical loads with equal resistance.
final class TwoLampSimulation {
  final LampTopology topology;
  final bool lamp1Open;

  const TwoLampSimulation({required this.topology, required this.lamp1Open});

  double get sourceVoltage => 12.0;

  LampResult get _healthyLamp => switch (topology) {
    LampTopology.parallel => LampResult._(
      activity: LampActivity.nominal,
      indication: VoltageIndication(sourceVoltage),
    ),
    LampTopology.series => LampResult._(
      activity: LampActivity.reduced,
      indication: VoltageIndication(sourceVoltage / 2, isApproximate: true),
    ),
  };

  LampResult get lamp1 => lamp1Open
      ? const LampResult._(
          activity: LampActivity.off,
          indication: OpenCircuitIndication(),
        )
      : _healthyLamp;

  LampResult get lamp2 => lamp1Open && topology == LampTopology.series
      ? const LampResult._(
          activity: LampActivity.off,
          indication: NoCurrentIndication(),
        )
      : _healthyLamp;
}
