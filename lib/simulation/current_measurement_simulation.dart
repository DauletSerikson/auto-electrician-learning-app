import 'multimeter.dart';

enum CurrentConnection { disconnected, series, acrossBattery, acrossLamp }

enum CurrentMeasurementErrorReason {
  wrongMode,
  wrongPort,
  disconnected,
  parallelAcrossLoad,
  incorrectSetup,
}

sealed class CurrentMeasurementReadout {
  const CurrentMeasurementReadout();
}

final class FuseBlownReadout extends CurrentMeasurementReadout {
  const FuseBlownReadout();
}

final class OffReadout extends CurrentMeasurementReadout {
  const OffReadout();
}

final class WarningReadout extends CurrentMeasurementReadout {
  const WarningReadout();
}

final class UnavailableReadout extends CurrentMeasurementReadout {
  const UnavailableReadout();
}

final class NumericReadout extends CurrentMeasurementReadout {
  final double value;

  const NumericReadout(this.value);
}

/// A snapshot of the exercise's existing rules; reading it never blows a fuse.
final class CurrentMeasurementSimulation {
  final MultimeterMode mode;
  final MultimeterPort redPort;
  final CurrentConnection connection;
  final bool meterFuseBlown;
  final double sourceVoltage;
  final double loadCurrent;

  const CurrentMeasurementSimulation({
    required this.mode,
    required this.redPort,
    required this.connection,
    required this.meterFuseBlown,
    required this.sourceVoltage,
    required this.loadCurrent,
  });

  bool get meterConfiguredForCurrent =>
      mode == MultimeterMode.current && redPort == MultimeterPort.current;

  bool get correctSetup =>
      !meterFuseBlown &&
      meterConfiguredForCurrent &&
      connection == CurrentConnection.series;

  bool get dangerousBatteryConnection =>
      !meterFuseBlown &&
      meterConfiguredForCurrent &&
      connection == CurrentConnection.acrossBattery;

  CurrentMeasurementReadout get readout {
    if (meterFuseBlown) return const FuseBlownReadout();
    if (mode == MultimeterMode.off) return const OffReadout();
    if (dangerousBatteryConnection) return const WarningReadout();
    // Preserve the exercise's voltage readout even with the current input.
    if (mode == MultimeterMode.dcVoltage) {
      return NumericReadout(
        connection == CurrentConnection.acrossBattery ? sourceVoltage : 0,
      );
    }
    if (mode == MultimeterMode.current) {
      if (redPort != MultimeterPort.current) {
        return const UnavailableReadout();
      }
      if (connection == CurrentConnection.series) {
        return NumericReadout(loadCurrent);
      }
      if (connection == CurrentConnection.acrossLamp) {
        return const WarningReadout();
      }
      return const NumericReadout(0);
    }
    return const UnavailableReadout();
  }

  /// The legacy error fallback also applies to a correct configuration.
  /// The widget displays this reason only after an unsuccessful check.
  CurrentMeasurementErrorReason get errorReason {
    if (mode != MultimeterMode.current) {
      return CurrentMeasurementErrorReason.wrongMode;
    }
    if (redPort != MultimeterPort.current) {
      return CurrentMeasurementErrorReason.wrongPort;
    }
    if (connection == CurrentConnection.disconnected) {
      return CurrentMeasurementErrorReason.disconnected;
    }
    if (connection == CurrentConnection.acrossLamp) {
      return CurrentMeasurementErrorReason.parallelAcrossLoad;
    }
    return CurrentMeasurementErrorReason.incorrectSetup;
  }
}
