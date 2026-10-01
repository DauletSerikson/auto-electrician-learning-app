import 'package:electrician/simulation/voltage_drop_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const points = VoltageDropPoint.values;

  for (final loadOn in [true, false]) {
    test('potentials with load ${loadOn ? 'on' : 'off'}', () {
      final simulation = VoltageDropSimulation(
        sourceVoltage: 12.6,
        faultVoltageDrop: 4.0,
        loadOn: loadOn,
      );
      expect(simulation.potentialAt(VoltageDropPoint.batteryPositive), 12.6);
      expect(
        simulation.potentialAt(VoltageDropPoint.afterFault),
        closeTo(loadOn ? 8.6 : 12.6, 1e-10),
      );
      expect(simulation.potentialAt(VoltageDropPoint.ground), 0);
    });

    // Explicit expected readings, ordered as A, B, C for each probe.
    final readings = loadOn
        ? [
            [0.0, 4.0, 12.6],
            [-4.0, 0.0, 8.6],
            [-12.6, -8.6, 0.0],
          ]
        : [
            [0.0, 0.0, 12.6],
            [0.0, 0.0, 12.6],
            [-12.6, -12.6, 0.0],
          ];
    for (var red = 0; red < points.length; red++) {
      for (var black = 0; black < points.length; black++) {
        test('${points[red].name} to ${points[black].name}, load $loadOn', () {
          final simulation = VoltageDropSimulation(
            sourceVoltage: 12.6,
            faultVoltageDrop: 4.0,
            loadOn: loadOn,
            redPoint: points[red],
            blackPoint: points[black],
          );
          expect(simulation.meterReading, closeTo(readings[red][black], 1e-10));
          expect(simulation.probesConnected, isTrue);
          expect(simulation.correctSetup, loadOn && red == 0 && black == 1);
        });
      }
    }

    final missingProbes = [
      (red: null, black: null),
      (red: VoltageDropPoint.batteryPositive, black: null),
      (red: null, black: VoltageDropPoint.afterFault),
    ];
    for (final probes in missingProbes) {
      test('missing probes $probes, load $loadOn', () {
        final simulation = VoltageDropSimulation(
          sourceVoltage: 12.6,
          faultVoltageDrop: 4.0,
          loadOn: loadOn,
          redPoint: probes.red,
          blackPoint: probes.black,
        );
        expect(simulation.meterReading, isNull);
        expect(simulation.probesConnected, isFalse);
        expect(simulation.correctSetup, isFalse);
      });
    }
  }

  test('uses supplied source and fault drop rather than lesson constants', () {
    const simulation = VoltageDropSimulation(
      sourceVoltage: 14.0,
      faultVoltageDrop: 1.5,
      loadOn: true,
      redPoint: VoltageDropPoint.batteryPositive,
      blackPoint: VoltageDropPoint.afterFault,
    );
    expect(simulation.potentialAt(VoltageDropPoint.afterFault), 12.5);
    expect(simulation.meterReading, 1.5);
    expect(simulation.correctSetup, isTrue);
  });
}
