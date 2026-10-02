enum MultimeterMode {
  off,
  dcVoltage,
  acVoltage,
  resistance,
  continuity,
  current,
}

enum MultimeterPort { voltageResistance, current }

/// The required red input, or null when the instrument is off.
MultimeterPort? requiredRedPort(MultimeterMode mode) => switch (mode) {
  MultimeterMode.off => null,
  MultimeterMode.dcVoltage ||
  MultimeterMode.acVoltage ||
  MultimeterMode.resistance ||
  MultimeterMode.continuity => MultimeterPort.voltageResistance,
  MultimeterMode.current => MultimeterPort.current,
};
