import 'package:electrician/simulation/current_measurement_simulation.dart';
import 'package:electrician/simulation/multimeter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Each row lists disconnected, series, acrossBattery, acrossLamp readouts.
  // Numeric inputs deliberately retain more precision than the widget displays.
  const rows = [
    (
      mode: MultimeterMode.off,
      port: MultimeterPort.voltageResistance,
      readings: <Object>['off', 'off', 'off', 'off'],
    ),
    (
      mode: MultimeterMode.off,
      port: MultimeterPort.current,
      readings: <Object>['off', 'off', 'off', 'off'],
    ),
    (
      mode: MultimeterMode.dcVoltage,
      port: MultimeterPort.voltageResistance,
      readings: <Object>[0.0, 0.0, 14.257, 0.0],
    ),
    (
      mode: MultimeterMode.dcVoltage,
      port: MultimeterPort.current,
      readings: <Object>[0.0, 0.0, 14.257, 0.0],
    ),
    (
      mode: MultimeterMode.current,
      port: MultimeterPort.voltageResistance,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
    (
      mode: MultimeterMode.current,
      port: MultimeterPort.current,
      readings: <Object>[0.0, 2.345, 'warning', 'warning'],
    ),
    (
      mode: MultimeterMode.acVoltage,
      port: MultimeterPort.voltageResistance,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
    (
      mode: MultimeterMode.acVoltage,
      port: MultimeterPort.current,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
    (
      mode: MultimeterMode.resistance,
      port: MultimeterPort.voltageResistance,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
    (
      mode: MultimeterMode.resistance,
      port: MultimeterPort.current,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
    (
      mode: MultimeterMode.continuity,
      port: MultimeterPort.voltageResistance,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
    (
      mode: MultimeterMode.continuity,
      port: MultimeterPort.current,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
    ),
  ];
  const connectionErrors = {
    CurrentConnection.disconnected: CurrentMeasurementErrorReason.disconnected,
    CurrentConnection.series: CurrentMeasurementErrorReason.incorrectSetup,
    CurrentConnection.acrossBattery:
        CurrentMeasurementErrorReason.incorrectSetup,
    CurrentConnection.acrossLamp:
        CurrentMeasurementErrorReason.parallelAcrossLoad,
  };

  for (final row in rows) {
    for (final connection in CurrentConnection.values) {
      for (final blown in [false, true]) {
        test(
          '${row.mode.name}/${row.port.name}/${connection.name}/fuse=$blown',
          () {
            final simulation = CurrentMeasurementSimulation(
              mode: row.mode,
              redPort: row.port,
              connection: connection,
              meterFuseBlown: blown,
              sourceVoltage: 14.257,
              loadCurrent: 2.345,
            );
            final configured =
                row.mode == MultimeterMode.current &&
                row.port == MultimeterPort.current;
            expect(simulation.meterConfiguredForCurrent, configured);
            expect(
              simulation.correctSetup,
              !blown && configured && connection == CurrentConnection.series,
            );
            expect(
              simulation.dangerousBatteryConnection,
              !blown &&
                  configured &&
                  connection == CurrentConnection.acrossBattery,
            );

            final readout = simulation.readout;
            if (blown) {
              expect(readout, isA<FuseBlownReadout>());
            } else {
              final expected = row.readings[connection.index];
              switch (expected) {
                case double value:
                  expect(readout, isA<NumericReadout>());
                  expect((readout as NumericReadout).value, value);
                case 'off':
                  expect(readout, isA<OffReadout>());
                case 'warning':
                  expect(readout, isA<WarningReadout>());
                case 'unavailable':
                  expect(readout, isA<UnavailableReadout>());
                default:
                  fail('Unexpected readout fixture: $expected');
              }
            }
            final expectedError = row.mode != MultimeterMode.current
                ? CurrentMeasurementErrorReason.wrongMode
                : row.port != MultimeterPort.current
                ? CurrentMeasurementErrorReason.wrongPort
                : connectionErrors[connection];
            expect(simulation.errorReason, expectedError);
          },
        );
      }
    }
  }

  test('dangerous snapshot remains immutable and never blows its own fuse', () {
    const simulation = CurrentMeasurementSimulation(
      mode: MultimeterMode.current,
      redPort: MultimeterPort.current,
      connection: CurrentConnection.acrossBattery,
      meterFuseBlown: false,
      sourceVoltage: 0,
      loadCurrent: 100,
    );
    for (var i = 0; i < 3; i++) {
      expect(simulation.dangerousBatteryConnection, isTrue);
      expect(simulation.readout, isA<WarningReadout>());
      expect(simulation.correctSetup, isFalse);
      expect(
        simulation.errorReason,
        CurrentMeasurementErrorReason.incorrectSetup,
      );
      expect(simulation.meterFuseBlown, isFalse);
      expect(simulation.mode, MultimeterMode.current);
      expect(simulation.redPort, MultimeterPort.current);
      expect(simulation.connection, CurrentConnection.acrossBattery);
      expect(simulation.sourceVoltage, 0);
      expect(simulation.loadCurrent, 100);
    }
  });
}
