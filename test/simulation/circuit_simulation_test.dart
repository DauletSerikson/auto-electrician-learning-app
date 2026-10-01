import 'package:electrician/simulation/circuit_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void expectLamp(
  LampResult result,
  LampActivity activity,
  LampIndication indication,
) {
  expect(result.activity, activity);
  expect(result.isActive, activity != LampActivity.off);
  expect(result.activity.isActive, result.isActive);
  switch (indication) {
    case VoltageIndication(:final volts, :final isApproximate):
      expect(result.indication, isA<VoltageIndication>());
      final actual = result.indication as VoltageIndication;
      expect(actual.volts, volts);
      expect(actual.isApproximate, isApproximate);
    case OpenCircuitIndication():
      expect(result.indication, isA<OpenCircuitIndication>());
    case NoCurrentIndication():
      expect(result.indication, isA<NoCurrentIndication>());
  }
}

void main() {
  for (final closed in [false, true]) {
    test('simple lamp is active only when closed=$closed', () {
      final simulation = SimpleLampSimulation(isClosed: closed);
      expect(simulation.isClosed, closed);
      expect(simulation.lampActive, closed);
    });
  }

  final cases = [
    (
      topology: LampTopology.parallel,
      open: false,
      activity1: LampActivity.nominal,
      indication1: const VoltageIndication(12),
      activity2: LampActivity.nominal,
      indication2: const VoltageIndication(12),
    ),
    (
      topology: LampTopology.series,
      open: false,
      activity1: LampActivity.reduced,
      indication1: const VoltageIndication(6, isApproximate: true),
      activity2: LampActivity.reduced,
      indication2: const VoltageIndication(6, isApproximate: true),
    ),
    (
      topology: LampTopology.parallel,
      open: true,
      activity1: LampActivity.off,
      indication1: const OpenCircuitIndication(),
      activity2: LampActivity.nominal,
      indication2: const VoltageIndication(12),
    ),
    (
      topology: LampTopology.series,
      open: true,
      activity1: LampActivity.off,
      indication1: const OpenCircuitIndication(),
      activity2: LampActivity.off,
      indication2: const NoCurrentIndication(),
    ),
  ];

  for (final scenario in cases) {
    test('${scenario.topology.name}, lamp1Open=${scenario.open}', () {
      final simulation = TwoLampSimulation(
        topology: scenario.topology,
        lamp1Open: scenario.open,
      );
      expect(simulation.topology, scenario.topology);
      expect(simulation.lamp1Open, scenario.open);
      expect(simulation.sourceVoltage, 12);
      expectLamp(simulation.lamp1, scenario.activity1, scenario.indication1);
      expectLamp(simulation.lamp2, scenario.activity2, scenario.indication2);
    });
  }

  test('new configurations do not change previously obtained results', () {
    const original = TwoLampSimulation(
      topology: LampTopology.series,
      lamp1Open: false,
    );
    final lamp1 = original.lamp1;
    final lamp2 = original.lamp2;
    const faulty = TwoLampSimulation(
      topology: LampTopology.series,
      lamp1Open: true,
    );
    expectLamp(faulty.lamp1, LampActivity.off, const OpenCircuitIndication());
    expectLamp(faulty.lamp2, LampActivity.off, const NoCurrentIndication());
    const parallel = TwoLampSimulation(
      topology: LampTopology.parallel,
      lamp1Open: true,
    );
    expectLamp(
      parallel.lamp2,
      LampActivity.nominal,
      const VoltageIndication(12),
    );
    for (final result in [lamp1, lamp2, original.lamp1, original.lamp2]) {
      expectLamp(
        result,
        LampActivity.reduced,
        const VoltageIndication(6, isApproximate: true),
      );
    }
  });
}
