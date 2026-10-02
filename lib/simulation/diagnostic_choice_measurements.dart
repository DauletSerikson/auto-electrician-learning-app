enum DiagnosticChoiceTest {
  batteryVoltage,
  fuseInputVoltage,
  fuseOutputVoltage,
  lampPositiveVoltage,
  lampGroundVoltage,
}

/// Fixed voltage table for the diagnostic choice exercise.
/// Unknown fault strings retain the exercise's existing fallback readings.
final class DiagnosticChoiceMeasurements {
  final String faultType;
  final double sourceVoltage;

  const DiagnosticChoiceMeasurements({
    required this.faultType,
    required this.sourceVoltage,
  });

  double voltageFor(DiagnosticChoiceTest test) => switch (test) {
    DiagnosticChoiceTest.batteryVoltage ||
    DiagnosticChoiceTest.fuseInputVoltage => sourceVoltage,
    DiagnosticChoiceTest.fuseOutputVoltage =>
      faultType == 'blownFuse' ? 0.0 : sourceVoltage,
    DiagnosticChoiceTest.lampPositiveVoltage =>
      faultType == 'blownFuse' || faultType == 'positiveWireOpen'
          ? 0.0
          : sourceVoltage,
    DiagnosticChoiceTest.lampGroundVoltage =>
      faultType == 'groundOpen' ? sourceVoltage : 0.0,
  };
}
