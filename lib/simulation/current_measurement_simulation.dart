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
  final double meterFuseRating;

  const CurrentMeasurementSimulation({
    required this.mode,
    required this.redPort,
    required this.connection,
    required this.meterFuseBlown,
    required this.sourceVoltage,
    required this.loadCurrent,
    required this.meterFuseRating,
  });

  bool get meterConfiguredForCurrent =>
      mode == MultimeterMode.current && redPort == MultimeterPort.current;

  bool get correctSetup =>
      !meterFuseBlown &&
      !currentInputOverload &&
      meterConfiguredForCurrent &&
      connection == CurrentConnection.series;

  /// Educational instantaneous overload model, without a time-current curve.
  bool get currentInputOverload =>
      !meterFuseBlown &&
      meterConfiguredForCurrent &&
      connection == CurrentConnection.series &&
      loadCurrent > meterFuseRating;

  bool get shouldBlowFuse => dangerousBatteryConnection || currentInputOverload;

  bool get dangerousBatteryConnection =>
      !meterFuseBlown &&
      meterConfiguredForCurrent &&
      connection == CurrentConnection.acrossBattery;

  CurrentMeasurementReadout get readout {
    if (meterFuseBlown || currentInputOverload) return const FuseBlownReadout();
    if (mode == MultimeterMode.off) return const OffReadout();
    if (dangerousBatteryConnection) return const WarningReadout();
    if (mode == MultimeterMode.dcVoltage) {
      if (redPort != MultimeterPort.voltageResistance) {
        return const UnavailableReadout();
      }
      // Parallel presets use positive-to-negative polarity. The load is
      // connected between the source and ground in this exercise.
      return NumericReadout(switch (connection) {
        CurrentConnection.acrossBattery ||
        CurrentConnection.acrossLamp => sourceVoltage,
        CurrentConnection.disconnected || CurrentConnection.series => 0,
      });
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
