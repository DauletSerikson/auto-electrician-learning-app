enum DiagnosticTest {
  batteryVoltage,
  fuseInputVoltage,
  fuseOutputVoltage,
  lampPositiveVoltage,
  lampGroundVoltage,
  wireContinuity,
}

sealed class DiagnosticCaseMeasurementResult {
  const DiagnosticCaseMeasurementResult();
}

final class DiagnosticCaseVoltage extends DiagnosticCaseMeasurementResult {
  final double value;
  const DiagnosticCaseVoltage(this.value);
}

final class DiagnosticCaseContinuity extends DiagnosticCaseMeasurementResult {
  final double resistance;
  final bool beep;
  const DiagnosticCaseContinuity({
    required this.resistance,
    required this.beep,
  });
}

final class DiagnosticCaseOpenLoop extends DiagnosticCaseMeasurementResult {
  const DiagnosticCaseOpenLoop();
}

final class DiagnosticCaseForbidden extends DiagnosticCaseMeasurementResult {
  const DiagnosticCaseForbidden();
}

/// Pure readings for the current circuit inputs, without measurement history.
final class DiagnosticCaseMeasurements {
  final String faultType;
  final double sourceVoltage;
  final bool powered;

  const DiagnosticCaseMeasurements({
    required this.faultType,
    required this.sourceVoltage,
    required this.powered,
  });

  DiagnosticCaseMeasurementResult resultFor(DiagnosticTest test) =>
      switch (test) {
        // Preserve the original exercise's fixed unpowered battery reading.
        DiagnosticTest.batteryVoltage => DiagnosticCaseVoltage(
          powered ? sourceVoltage : 12.6,
        ),
        DiagnosticTest.fuseInputVoltage || DiagnosticTest.fuseOutputVoltage =>
          DiagnosticCaseVoltage(powered ? sourceVoltage : 0.0),
        DiagnosticTest.lampPositiveVoltage => DiagnosticCaseVoltage(
          powered && faultType != 'positiveWireOpen' ? sourceVoltage : 0.0,
        ),
        DiagnosticTest.lampGroundVoltage => const DiagnosticCaseVoltage(0.0),
        DiagnosticTest.wireContinuity =>
          powered
              ? const DiagnosticCaseForbidden()
              : faultType == 'positiveWireOpen'
              ? const DiagnosticCaseOpenLoop()
              : const DiagnosticCaseContinuity(resistance: 0.3, beep: true),
      };
}
