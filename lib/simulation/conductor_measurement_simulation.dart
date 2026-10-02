import 'multimeter.dart';

enum WirePoint { none, pointA, pointB }

enum ConductorMeasurementKind { resistance, continuity }

enum ConductorMeasurementErrorReason {
  unsafeOhmicMeasurement,
  wrongMode,
  wrongPort,
  powered,
  missingProbes,
  samePoint,
  incorrectSetup,
}

sealed class ConductorMeasurementReadout {
  const ConductorMeasurementReadout();
}

final class ConductorOffReadout extends ConductorMeasurementReadout {
  const ConductorOffReadout();
}

final class ConductorWarningReadout extends ConductorMeasurementReadout {
  const ConductorWarningReadout();
}

final class ConductorUnavailableReadout extends ConductorMeasurementReadout {
  const ConductorUnavailableReadout();
}

final class ConductorOpenLoopReadout extends ConductorMeasurementReadout {
  const ConductorOpenLoopReadout();
}

final class ConductorNumericReadout extends ConductorMeasurementReadout {
  final double value;
  const ConductorNumericReadout(this.value);
}

/// Immutable evaluation shared by resistance and continuity exercises.
final class ConductorMeasurementSimulation {
  static const double continuityThreshold = 50.0;

  final MultimeterMode mode;
  final MultimeterPort redPort;
  final WirePoint redWirePoint;
  final WirePoint blackWirePoint;
  final bool powered;
  final bool broken;
  final double resistance;
  final ConductorMeasurementKind kind;

  const ConductorMeasurementSimulation({
    required this.mode,
    required this.redPort,
    required this.redWirePoint,
    required this.blackWirePoint,
    required this.powered,
    required this.broken,
    required this.resistance,
    required this.kind,
  });

  bool get probesConnected =>
      redWirePoint != WirePoint.none && blackWirePoint != WirePoint.none;

  bool get probesAcrossWire =>
      probesConnected && redWirePoint != blackWirePoint;

  MultimeterMode get requiredMode => switch (kind) {
    ConductorMeasurementKind.resistance => MultimeterMode.resistance,
    ConductorMeasurementKind.continuity => MultimeterMode.continuity,
  };

  bool get unsafeOhmicMeasurement =>
      powered &&
      (mode == MultimeterMode.resistance ||
          mode == MultimeterMode.continuity) &&
      probesConnected;

  bool get correctSetup =>
      !powered &&
      mode == requiredMode &&
      redPort == requiredRedPort(mode) &&
      probesAcrossWire;

  bool get success => correctSetup;

  bool get continuityBeep =>
      mode == MultimeterMode.continuity &&
      !powered &&
      redPort == requiredRedPort(mode) &&
      probesAcrossWire &&
      !broken &&
      resistance <= continuityThreshold;

  ConductorMeasurementReadout get readout {
    if (mode == MultimeterMode.off) return const ConductorOffReadout();
    // Intentionally ignores port, fault and whether probes share a point.
    if (unsafeOhmicMeasurement) return const ConductorWarningReadout();
    if (mode != MultimeterMode.resistance &&
        mode != MultimeterMode.continuity) {
      return const ConductorNumericReadout(0);
    }
    if (redPort != requiredRedPort(mode)) {
      return const ConductorUnavailableReadout();
    }
    if (!probesAcrossWire) return const ConductorOpenLoopReadout();
    // Across-wire powered setups have already returned the danger readout.
    if (broken) return const ConductorOpenLoopReadout();
    return ConductorNumericReadout(resistance);
  }

  /// Procedure errors are independent of readout and of conductor integrity.
  /// Used after a failed check; correct setups retain the legacy fallback.
  ConductorMeasurementErrorReason get errorReason {
    if (unsafeOhmicMeasurement) {
      return ConductorMeasurementErrorReason.unsafeOhmicMeasurement;
    }
    if (mode != requiredMode) return ConductorMeasurementErrorReason.wrongMode;
    if (redPort != requiredRedPort(mode)) {
      return ConductorMeasurementErrorReason.wrongPort;
    }
    if (powered) return ConductorMeasurementErrorReason.powered;
    if (!probesConnected) return ConductorMeasurementErrorReason.missingProbes;
    if (!probesAcrossWire) return ConductorMeasurementErrorReason.samePoint;
    return ConductorMeasurementErrorReason.incorrectSetup;
  }
}
