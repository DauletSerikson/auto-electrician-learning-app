import 'multimeter.dart';

enum BatteryTerminal { none, positive, negative }

enum BatteryVoltageErrorReason {
  unsafeCurrentConnection,
  wrongMode,
  wrongPort,
  missingProbes,
  reversedPolarity,
  sameTerminal,
  incorrectSetup,
}

sealed class BatteryVoltageReadout {
  const BatteryVoltageReadout();
}

final class BatteryOffReadout extends BatteryVoltageReadout {
  const BatteryOffReadout();
}

final class BatteryWarningReadout extends BatteryVoltageReadout {
  const BatteryWarningReadout();
}

final class BatteryOpenLoopReadout extends BatteryVoltageReadout {
  const BatteryOpenLoopReadout();
}

final class BatteryNumericReadout extends BatteryVoltageReadout {
  final double value;
  const BatteryNumericReadout(this.value);
}

/// Immutable evaluation of the battery exercise, without hardware transitions.
final class BatteryVoltageSimulation {
  final MultimeterMode mode;
  final MultimeterPort redPort;
  final BatteryTerminal redTerminal;
  final BatteryTerminal blackTerminal;
  final double sourceVoltage;

  const BatteryVoltageSimulation({
    required this.mode,
    required this.redPort,
    required this.redTerminal,
    required this.blackTerminal,
    required this.sourceVoltage,
  });

  bool get probesConnected =>
      redTerminal != BatteryTerminal.none &&
      blackTerminal != BatteryTerminal.none;

  bool get probesDifferent => probesConnected && redTerminal != blackTerminal;

  bool get correctVoltageSetup =>
      mode == MultimeterMode.dcVoltage &&
      redPort == requiredRedPort(mode) &&
      redTerminal == BatteryTerminal.positive &&
      blackTerminal == BatteryTerminal.negative;

  bool get reversedVoltageSetup =>
      mode == MultimeterMode.dcVoltage &&
      redPort == requiredRedPort(mode) &&
      redTerminal == BatteryTerminal.negative &&
      blackTerminal == BatteryTerminal.positive;

  bool get unsafeCurrentConnection =>
      mode == MultimeterMode.current &&
      redPort == requiredRedPort(mode) &&
      probesDifferent;

  bool get success => correctVoltageSetup;

  BatteryVoltageReadout get readout {
    if (mode == MultimeterMode.off) return const BatteryOffReadout();
    if (unsafeCurrentConnection) return const BatteryWarningReadout();
    if (mode == MultimeterMode.dcVoltage && redPort == requiredRedPort(mode)) {
      if (correctVoltageSetup) return BatteryNumericReadout(sourceVoltage);
      if (reversedVoltageSetup) return BatteryNumericReadout(-sourceVoltage);
      return const BatteryNumericReadout(0);
    }
    // Preserve OL even with the current port; no universal port validation.
    if (mode == MultimeterMode.resistance ||
        mode == MultimeterMode.continuity) {
      return const BatteryOpenLoopReadout();
    }
    return const BatteryNumericReadout(0);
  }

  /// Used after a failed check. A correct setup retains the legacy fallback.
  BatteryVoltageErrorReason get errorReason {
    if (unsafeCurrentConnection) {
      return BatteryVoltageErrorReason.unsafeCurrentConnection;
    }
    if (mode != MultimeterMode.dcVoltage) {
      return BatteryVoltageErrorReason.wrongMode;
    }
    if (redPort != requiredRedPort(mode)) {
      return BatteryVoltageErrorReason.wrongPort;
    }
    if (!probesConnected) return BatteryVoltageErrorReason.missingProbes;
    if (reversedVoltageSetup) return BatteryVoltageErrorReason.reversedPolarity;
    if (redTerminal == blackTerminal) {
      return BatteryVoltageErrorReason.sameTerminal;
    }
    return BatteryVoltageErrorReason.incorrectSetup;
  }
}
