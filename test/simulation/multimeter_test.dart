import 'package:electrician/simulation/multimeter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedPorts = {
    MultimeterMode.off: null,
    MultimeterMode.dcVoltage: MultimeterPort.voltageResistance,
    MultimeterMode.acVoltage: MultimeterPort.voltageResistance,
    MultimeterMode.resistance: MultimeterPort.voltageResistance,
    MultimeterMode.continuity: MultimeterPort.voltageResistance,
    MultimeterMode.current: MultimeterPort.current,
  };

  for (final mode in MultimeterMode.values) {
    test('${mode.name} requires the expected red port', () {
      expect(requiredRedPort(mode), expectedPorts[mode]);
    });

    final expectedPort = expectedPorts[mode];
    if (expectedPort == null) continue;

    test('${mode.name} is compatible with its required port', () {
      expect(expectedPort == requiredRedPort(mode), isTrue);
    });

    test('${mode.name} is incompatible with the alternative port', () {
      final alternative = expectedPort == MultimeterPort.current
          ? MultimeterPort.voltageResistance
          : MultimeterPort.current;
      expect(alternative == requiredRedPort(mode), isFalse);
    });
  }
}
