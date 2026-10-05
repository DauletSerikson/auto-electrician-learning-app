import 'package:electrician/simulation/current_measurement_simulation.dart';
import 'package:electrician/simulation/multimeter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final current in [9.99, 10.0, 10.01]) {
    test('series overload boundary $current / 10 A is immutable', () {
      final simulation = CurrentMeasurementSimulation(
        mode: MultimeterMode.current,
        redPort: MultimeterPort.current,
        connection: CurrentConnection.series,
        meterFuseBlown: false,
        sourceVoltage: 12.6,
        loadCurrent: current,
        meterFuseRating: 10,
      );
      final overloaded = current > 10;
      expect(simulation.currentInputOverload, overloaded);
      expect(simulation.shouldBlowFuse, overloaded);
      expect(simulation.dangerousBatteryConnection, isFalse);
      expect(simulation.correctSetup, !overloaded);
      for (var i = 0; i < 2; i++) {
        if (overloaded) {
          expect(simulation.readout, isA<FuseBlownReadout>());
        } else {
          expect((simulation.readout as NumericReadout).value, current);
        }
        expect(simulation.meterFuseBlown, isFalse);
      }
    });
  }

  test('overload is restricted to current mode, current port and series', () {
    for (final mode in MultimeterMode.values) {
      for (final port in MultimeterPort.values) {
        for (final connection in CurrentConnection.values) {
          final simulation = CurrentMeasurementSimulation(
            mode: mode,
            redPort: port,
            connection: connection,
            meterFuseBlown: false,
            sourceVoltage: 12.6,
            loadCurrent: 100,
            meterFuseRating: 10,
          );
          final configured =
              mode == MultimeterMode.current && port == MultimeterPort.current;
          expect(
            simulation.currentInputOverload,
            configured && connection == CurrentConnection.series,
          );
          expect(
            simulation.shouldBlowFuse,
            configured &&
                (connection == CurrentConnection.series ||
                    connection == CurrentConnection.acrossBattery),
          );
        }
      }
    }
  });

  test('parallel current behavior ignores load current and zero source', () {
    for (final current in [0.0, 2.0, 100.0]) {
      for (final voltage in [0.0, 12.6]) {
        for (final connection in [
          CurrentConnection.acrossBattery,
          CurrentConnection.acrossLamp,
        ]) {
          final simulation = CurrentMeasurementSimulation(
            mode: MultimeterMode.current,
            redPort: MultimeterPort.current,
            connection: connection,
            meterFuseBlown: false,
            sourceVoltage: voltage,
            loadCurrent: current,
            meterFuseRating: 10,
          );
          expect(simulation.currentInputOverload, isFalse);
          expect(
            simulation.shouldBlowFuse,
            connection == CurrentConnection.acrossBattery,
          );
          expect(simulation.readout, isA<WarningReadout>());
          expect(simulation.correctSetup, isFalse);
        }
      }
    }
  });

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
      readings: <Object>[0.0, 0.0, 14.257, 14.257],
    ),
    (
      mode: MultimeterMode.dcVoltage,
      port: MultimeterPort.current,
      readings: <Object>[
        'unavailable',
        'unavailable',
        'unavailable',
        'unavailable',
      ],
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
              meterFuseRating: 10,
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
      meterFuseRating: 10,
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
