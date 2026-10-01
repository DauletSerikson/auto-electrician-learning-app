enum VoltageDropPoint { batteryPositive, afterFault, ground }

/// The exercise's fixed voltage drop applies only while the load is on.
final class VoltageDropSimulation {
  final double sourceVoltage;
  final double faultVoltageDrop;
  final bool loadOn;
  final VoltageDropPoint? redPoint;
  final VoltageDropPoint? blackPoint;

  const VoltageDropSimulation({
    required this.sourceVoltage,
    required this.faultVoltageDrop,
    required this.loadOn,
    this.redPoint,
    this.blackPoint,
  });

  double potentialAt(VoltageDropPoint point) => switch (point) {
    VoltageDropPoint.batteryPositive => sourceVoltage,
    VoltageDropPoint.afterFault =>
      loadOn ? sourceVoltage - faultVoltageDrop : sourceVoltage,
    VoltageDropPoint.ground => 0,
  };

  bool get probesConnected => redPoint != null && blackPoint != null;

  double? get meterReading {
    final red = redPoint;
    final black = blackPoint;
    if (red == null || black == null) {
      return null;
    }
    return potentialAt(red) - potentialAt(black);
  }

  /// The task requires the prescribed polarity as well as an active load.
  bool get correctSetup =>
      loadOn &&
      redPoint == VoltageDropPoint.batteryPositive &&
      blackPoint == VoltageDropPoint.afterFault;
}
