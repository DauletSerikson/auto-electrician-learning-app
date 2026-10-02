import 'package:electrician/simulation/diagnostic_choice_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Explicit rows in DiagnosticChoiceTest declaration order.
  const tables = <String, List<double>>{
    'blownFuse': [13.25, 13.25, 0.0, 0.0, 0.0],
    'positiveWireOpen': [13.25, 13.25, 13.25, 0.0, 0.0],
    'groundOpen': [13.25, 13.25, 13.25, 13.25, 13.25],
    // Observable fallback, not an officially supported fault.
    'unknownNonEmptyFault': [13.25, 13.25, 13.25, 13.25, 0.0],
  };

  for (final entry in tables.entries) {
    test('${entry.key} voltage table', () {
      final measurements = DiagnosticChoiceMeasurements(
        faultType: entry.key,
        sourceVoltage: 13.25,
      );
      for (final measurement in DiagnosticChoiceTest.values) {
        expect(
          measurements.voltageFor(measurement),
          entry.value[measurement.index],
          reason: measurement.name,
        );
      }
    });
  }

  test('zero source voltage gives zero for every fault and measurement', () {
    for (final fault in tables.keys) {
      final measurements = DiagnosticChoiceMeasurements(
        faultType: fault,
        sourceVoltage: 0.0,
      );
      for (final measurement in DiagnosticChoiceTest.values) {
        expect(
          measurements.voltageFor(measurement),
          0.0,
          reason: '$fault / ${measurement.name}',
        );
      }
    }
  });

  test('another source voltage is retained without rounding', () {
    const measurements = DiagnosticChoiceMeasurements(
      faultType: 'groundOpen',
      sourceVoltage: 14.375,
    );
    for (final measurement in DiagnosticChoiceTest.values) {
      expect(
        measurements.voltageFor(measurement),
        14.375,
        reason: measurement.name,
      );
    }
  });
}
