import 'package:electrician/simulation/battery_voltage_simulation.dart';
import 'package:electrician/simulation/multimeter.dart';
import 'package:flutter_test/flutter_test.dart';

BatteryVoltageSimulation _snapshot({
  MultimeterMode mode = MultimeterMode.dcVoltage,
  MultimeterPort port = MultimeterPort.voltageResistance,
  BatteryTerminal red = BatteryTerminal.positive,
  BatteryTerminal black = BatteryTerminal.negative,
  double voltage = 12.6,
}) => BatteryVoltageSimulation(
  mode: mode,
  redPort: port,
  redTerminal: red,
  blackTerminal: black,
  sourceVoltage: voltage,
);

Matcher _numeric(double value) => isA<BatteryNumericReadout>().having(
  (readout) => readout.value,
  'raw voltage',
  value,
);

void main() {
  final terminalCases = [
    (
      name: 'correct polarity',
      red: BatteryTerminal.positive,
      black: BatteryTerminal.negative,
      connected: true,
      different: true,
      correct: true,
      reversed: false,
      value: 12.6,
      error: BatteryVoltageErrorReason.incorrectSetup,
    ),
    (
      name: 'reverse polarity',
      red: BatteryTerminal.negative,
      black: BatteryTerminal.positive,
      connected: true,
      different: true,
      correct: false,
      reversed: true,
      value: -12.6,
      error: BatteryVoltageErrorReason.reversedPolarity,
    ),
    (
      name: 'same positive',
      red: BatteryTerminal.positive,
      black: BatteryTerminal.positive,
      connected: true,
      different: false,
      correct: false,
      reversed: false,
      value: 0.0,
      error: BatteryVoltageErrorReason.sameTerminal,
    ),
    (
      name: 'same negative',
      red: BatteryTerminal.negative,
      black: BatteryTerminal.negative,
      connected: true,
      different: false,
      correct: false,
      reversed: false,
      value: 0.0,
      error: BatteryVoltageErrorReason.sameTerminal,
    ),
    (
      name: 'missing red',
      red: BatteryTerminal.none,
      black: BatteryTerminal.negative,
      connected: false,
      different: false,
      correct: false,
      reversed: false,
      value: 0.0,
      error: BatteryVoltageErrorReason.missingProbes,
    ),
    (
      name: 'missing black',
      red: BatteryTerminal.positive,
      black: BatteryTerminal.none,
      connected: false,
      different: false,
      correct: false,
      reversed: false,
      value: 0.0,
      error: BatteryVoltageErrorReason.missingProbes,
    ),
    (
      name: 'both missing precedes same terminal',
      red: BatteryTerminal.none,
      black: BatteryTerminal.none,
      connected: false,
      different: false,
      correct: false,
      reversed: false,
      value: 0.0,
      error: BatteryVoltageErrorReason.missingProbes,
    ),
  ];
  for (final row in terminalCases) {
    test(row.name, () {
      final simulation = _snapshot(red: row.red, black: row.black);
      expect(simulation.probesConnected, row.connected);
      expect(simulation.probesDifferent, row.different);
      expect(simulation.correctVoltageSetup, row.correct);
      expect(simulation.reversedVoltageSetup, row.reversed);
      expect(simulation.unsafeCurrentConnection, isFalse);
      expect(simulation.success, row.correct);
      expect(simulation.readout, _numeric(row.value));
      expect(simulation.errorReason, row.error);
    });
  }

  final configurationCases = [
    (
      name: 'OFF precedes current port and connected terminals',
      mode: MultimeterMode.off,
      port: MultimeterPort.current,
      danger: false,
      readout: isA<BatteryOffReadout>(),
      error: BatteryVoltageErrorReason.wrongMode,
    ),
    (
      name: 'DC wrong port precedes reversed polarity',
      mode: MultimeterMode.dcVoltage,
      port: MultimeterPort.current,
      danger: false,
      readout: _numeric(0),
      error: BatteryVoltageErrorReason.wrongPort,
    ),
    (
      name: 'ohms voltage port',
      mode: MultimeterMode.resistance,
      port: MultimeterPort.voltageResistance,
      danger: false,
      readout: isA<BatteryOpenLoopReadout>(),
      error: BatteryVoltageErrorReason.wrongMode,
    ),
    (
      name: 'ohms current port keeps OL and mode error',
      mode: MultimeterMode.resistance,
      port: MultimeterPort.current,
      danger: false,
      readout: isA<BatteryOpenLoopReadout>(),
      error: BatteryVoltageErrorReason.wrongMode,
    ),
    (
      name: 'continuity voltage port',
      mode: MultimeterMode.continuity,
      port: MultimeterPort.voltageResistance,
      danger: false,
      readout: isA<BatteryOpenLoopReadout>(),
      error: BatteryVoltageErrorReason.wrongMode,
    ),
    (
      name: 'continuity current port keeps OL',
      mode: MultimeterMode.continuity,
      port: MultimeterPort.current,
      danger: false,
      readout: isA<BatteryOpenLoopReadout>(),
      error: BatteryVoltageErrorReason.wrongMode,
    ),
    (
      name: 'current voltage port is zero without danger',
      mode: MultimeterMode.current,
      port: MultimeterPort.voltageResistance,
      danger: false,
      readout: _numeric(0),
      error: BatteryVoltageErrorReason.wrongMode,
    ),
    (
      name: 'current danger precedes mode error with reverse terminals',
      mode: MultimeterMode.current,
      port: MultimeterPort.current,
      danger: true,
      readout: isA<BatteryWarningReadout>(),
      error: BatteryVoltageErrorReason.unsafeCurrentConnection,
    ),
  ];
  for (final row in configurationCases) {
    test(row.name, () {
      final simulation = _snapshot(
        mode: row.mode,
        port: row.port,
        red: BatteryTerminal.negative,
        black: BatteryTerminal.positive,
      );
      expect(simulation.probesConnected, isTrue);
      expect(simulation.probesDifferent, isTrue);
      expect(simulation.correctVoltageSetup, isFalse);
      expect(simulation.reversedVoltageSetup, isFalse);
      expect(simulation.unsafeCurrentConnection, row.danger);
      expect(simulation.success, isFalse);
      expect(simulation.readout, row.readout);
      expect(simulation.errorReason, row.error);
    });
  }

  test('wrong port precedes missing terminals', () {
    final simulation = _snapshot(
      port: MultimeterPort.current,
      red: BatteryTerminal.none,
      black: BatteryTerminal.none,
    );
    expect(simulation.readout, _numeric(0));
    expect(simulation.errorReason, BatteryVoltageErrorReason.wrongPort);
    expect(simulation.success, isFalse);
  });

  for (final red in [BatteryTerminal.none, BatteryTerminal.negative]) {
    test('current input needs different connected terminals red=$red', () {
      final simulation = _snapshot(
        mode: MultimeterMode.current,
        port: MultimeterPort.current,
        red: red,
      );
      expect(simulation.probesDifferent, isFalse);
      expect(simulation.unsafeCurrentConnection, isFalse);
      expect(simulation.readout, _numeric(0));
      expect(simulation.errorReason, BatteryVoltageErrorReason.wrongMode);
    });
  }

  test('numeric readout preserves raw source voltage', () {
    final simulation = _snapshot(voltage: 12.654);
    expect(simulation.readout, _numeric(12.654));
    expect(simulation.success, isTrue);
  });

  test('zero voltage does not change setup success or current danger', () {
    expect(_snapshot(voltage: 0).success, isTrue);
    expect(_snapshot(voltage: 0).readout, _numeric(0));
    final simulation = _snapshot(
      voltage: 0,
      mode: MultimeterMode.current,
      port: MultimeterPort.current,
    );
    expect(simulation.unsafeCurrentConnection, isTrue);
    expect(simulation.readout, isA<BatteryWarningReadout>());
    expect(simulation.success, isFalse);
  });
}
