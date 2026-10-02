import 'package:electrician/simulation/diagnostic_case_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fault in ['positiveWireOpen', 'unknownNonEmptyFault']) {
    for (final powered in [true, false]) {
      test('$fault complete semantic table powered=$powered', () {
        final measurements = DiagnosticCaseMeasurements(
          faultType: fault,
          sourceVoltage: 13.25,
          powered: powered,
        );
        final expectedVoltages = powered
            ? [
                13.25,
                13.25,
                13.25,
                fault == 'positiveWireOpen' ? 0.0 : 13.25,
                0.0,
              ]
            : [12.6, 0.0, 0.0, 0.0, 0.0];
        for (var i = 0; i < 5; i++) {
          final result = measurements.resultFor(DiagnosticTest.values[i]);
          expect(result, isA<DiagnosticCaseVoltage>());
          expect(
            (result as DiagnosticCaseVoltage).value,
            expectedVoltages[i],
            reason: DiagnosticTest.values[i].name,
          );
        }
        final continuity = measurements.resultFor(
          DiagnosticTest.wireContinuity,
        );
        if (powered) {
          expect(continuity, isA<DiagnosticCaseForbidden>());
        } else if (fault == 'positiveWireOpen') {
          expect(continuity, isA<DiagnosticCaseOpenLoop>());
        } else {
          expect(continuity, isA<DiagnosticCaseContinuity>());
          final result = continuity as DiagnosticCaseContinuity;
          expect(result.resistance, 0.3);
          expect(result.beep, isTrue);
        }
      });
    }
  }

  test(
    'zero voltage, open loop and forbidden are distinct semantic results',
    () {
      const powered = DiagnosticCaseMeasurements(
        faultType: 'positiveWireOpen',
        sourceVoltage: 13.25,
        powered: true,
      );
      const unpowered = DiagnosticCaseMeasurements(
        faultType: 'positiveWireOpen',
        sourceVoltage: 13.25,
        powered: false,
      );
      final zero = powered.resultFor(DiagnosticTest.lampPositiveVoltage);
      expect(zero, isA<DiagnosticCaseVoltage>());
      expect((zero as DiagnosticCaseVoltage).value, 0.0);
      expect(zero, isNot(isA<DiagnosticCaseOpenLoop>()));
      final openLoop = unpowered.resultFor(DiagnosticTest.wireContinuity);
      final forbidden = powered.resultFor(DiagnosticTest.wireContinuity);
      expect(openLoop, isA<DiagnosticCaseOpenLoop>());
      expect(openLoop, isNot(isA<DiagnosticCaseForbidden>()));
      expect(forbidden, isA<DiagnosticCaseForbidden>());
      expect(forbidden, isNot(isA<DiagnosticCaseOpenLoop>()));
    },
  );

  test(
    'source voltage remains unrounded while unpowered battery stays 12.6',
    () {
      for (final powered in [true, false]) {
        final measurements = DiagnosticCaseMeasurements(
          faultType: 'unknownNonEmptyFault',
          sourceVoltage: 14.375,
          powered: powered,
        );
        final battery = measurements.resultFor(
          DiagnosticTest.batteryVoltage,
        ) as DiagnosticCaseVoltage;
        expect(battery.value, powered ? 14.375 : 12.6);
        for (final test in [
          DiagnosticTest.fuseInputVoltage,
          DiagnosticTest.fuseOutputVoltage,
          DiagnosticTest.lampPositiveVoltage,
        ]) {
          final result = measurements.resultFor(test) as DiagnosticCaseVoltage;
          expect(result.value, powered ? 14.375 : 0.0);
        }
      }
    },
  );
}
