import 'package:electrician/simulation/conductor_measurement_simulation.dart';
import 'package:electrician/simulation/multimeter.dart';
import 'package:flutter_test/flutter_test.dart';

ConductorMeasurementSimulation _snapshot({
  ConductorMeasurementKind kind = ConductorMeasurementKind.resistance,
  MultimeterMode mode = MultimeterMode.resistance,
  MultimeterPort port = MultimeterPort.voltageResistance,
  WirePoint red = WirePoint.pointA,
  WirePoint black = WirePoint.pointB,
  bool powered = false,
  bool broken = false,
  double resistance = 0.3,
}) => ConductorMeasurementSimulation(
  kind: kind,
  mode: mode,
  redPort: port,
  redWirePoint: red,
  blackWirePoint: black,
  powered: powered,
  broken: broken,
  resistance: resistance,
);

Matcher _numeric(double value) => isA<ConductorNumericReadout>().having(
  (readout) => readout.value,
  'raw resistance',
  value,
);

void main() {
  for (final point in [WirePoint.pointA, WirePoint.pointB]) {
    for (final broken in [false, true]) {
      test(
        'same-point $point broken=$broken reads zero but cannot complete A–B',
        () {
          final simulation = _snapshot(
            kind: ConductorMeasurementKind.continuity,
            mode: MultimeterMode.continuity,
            red: point,
            black: point,
            broken: broken,
            resistance: 100,
          );
          expect(simulation.readout, _numeric(0));
          expect(simulation.continuityBeep, isTrue);
          expect(simulation.success, isFalse);
          expect(
            simulation.errorReason,
            ConductorMeasurementErrorReason.samePoint,
          );
        },
      );
    }
  }
  for (final kind in ConductorMeasurementKind.values) {
    final mode = kind == ConductorMeasurementKind.resistance
        ? MultimeterMode.resistance
        : MultimeterMode.continuity;
    final alternateMode = kind == ConductorMeasurementKind.resistance
        ? MultimeterMode.continuity
        : MultimeterMode.resistance;
    final continuity = kind == ConductorMeasurementKind.continuity;

    for (final broken in [false, true]) {
      test('$kind broken=$broken does not change procedure success', () {
        final simulation = _snapshot(kind: kind, mode: mode, broken: broken);
        expect(simulation.requiredMode, mode);
        expect(simulation.probesConnected, isTrue);
        expect(simulation.probesAcrossWire, isTrue);
        expect(simulation.correctSetup, isTrue);
        expect(simulation.success, isTrue);
        expect(simulation.unsafeOhmicMeasurement, isFalse);
        expect(
          simulation.readout,
          broken ? isA<ConductorOpenLoopReadout>() : _numeric(0.3),
        );
        expect(simulation.continuityBeep, continuity && !broken);
        expect(
          simulation.errorReason,
          ConductorMeasurementErrorReason.incorrectSetup,
        );
      });
    }

    test('$kind swapped probes are equivalent', () {
      final simulation = _snapshot(
        kind: kind,
        mode: mode,
        red: WirePoint.pointB,
        black: WirePoint.pointA,
      );
      expect(simulation.probesConnected, isTrue);
      expect(simulation.probesAcrossWire, isTrue);
      expect(simulation.correctSetup, isTrue);
      expect(simulation.success, isTrue);
      expect(simulation.readout, _numeric(0.3));
      expect(simulation.continuityBeep, continuity);
      expect(
        simulation.errorReason,
        ConductorMeasurementErrorReason.incorrectSetup,
      );
    });

    final probeCases = [
      (
        name: 'missing red',
        red: WirePoint.none,
        black: WirePoint.pointB,
        connected: false,
        error: ConductorMeasurementErrorReason.missingProbes,
      ),
      (
        name: 'missing black',
        red: WirePoint.pointA,
        black: WirePoint.none,
        connected: false,
        error: ConductorMeasurementErrorReason.missingProbes,
      ),
      (
        name: 'both missing before same point',
        red: WirePoint.none,
        black: WirePoint.none,
        connected: false,
        error: ConductorMeasurementErrorReason.missingProbes,
      ),
      (
        name: 'same A',
        red: WirePoint.pointA,
        black: WirePoint.pointA,
        connected: true,
        error: ConductorMeasurementErrorReason.samePoint,
      ),
      (
        name: 'same B',
        red: WirePoint.pointB,
        black: WirePoint.pointB,
        connected: true,
        error: ConductorMeasurementErrorReason.samePoint,
      ),
    ];
    for (final row in probeCases) {
      test('$kind ${row.name}', () {
        final simulation = _snapshot(
          kind: kind,
          mode: mode,
          red: row.red,
          black: row.black,
        );
        expect(simulation.probesConnected, row.connected);
        expect(simulation.probesAcrossWire, isFalse);
        expect(
          simulation.readout,
          row.connected ? _numeric(0) : isA<ConductorOpenLoopReadout>(),
        );
        expect(simulation.errorReason, row.error);
        expect(simulation.correctSetup, isFalse);
        expect(simulation.success, isFalse);
        expect(simulation.continuityBeep, continuity && row.connected);
      });
    }

    test('$kind alternate ohmic mode reads independently of procedure', () {
      final simulation = _snapshot(kind: kind, mode: alternateMode);
      expect(simulation.readout, _numeric(0.3));
      expect(simulation.continuityBeep, !continuity);
      expect(simulation.correctSetup, isFalse);
      expect(simulation.success, isFalse);
      expect(simulation.errorReason, ConductorMeasurementErrorReason.wrongMode);
    });

    for (final unsupportedMode in [
      MultimeterMode.off,
      MultimeterMode.dcVoltage,
      MultimeterMode.current,
    ]) {
      test('$kind $unsupportedMode precedes port, power and probe errors', () {
        final simulation = _snapshot(
          kind: kind,
          mode: unsupportedMode,
          port: MultimeterPort.current,
          powered: true,
          red: WirePoint.none,
        );
        expect(
          simulation.readout,
          unsupportedMode == MultimeterMode.off
              ? isA<ConductorOffReadout>()
              : _numeric(0),
        );
        expect(
          simulation.errorReason,
          ConductorMeasurementErrorReason.wrongMode,
        );
        expect(simulation.unsafeOhmicMeasurement, isFalse);
        expect(simulation.continuityBeep, isFalse);
        expect(simulation.success, isFalse);
      });
    }

    test(
      '$kind wrong port masks power/missing probes when danger is absent',
      () {
        final simulation = _snapshot(
          kind: kind,
          mode: mode,
          port: MultimeterPort.current,
          powered: true,
          red: WirePoint.none,
        );
        expect(simulation.readout, isA<ConductorUnavailableReadout>());
        expect(
          simulation.errorReason,
          ConductorMeasurementErrorReason.wrongPort,
        );
        expect(simulation.unsafeOhmicMeasurement, isFalse);
        expect(simulation.continuityBeep, isFalse);
        expect(simulation.success, isFalse);
      },
    );

    test('$kind wrong port masks broken and same-point readouts', () {
      final simulation = _snapshot(
        kind: kind,
        mode: mode,
        port: MultimeterPort.current,
        broken: true,
        black: WirePoint.pointA,
      );
      expect(simulation.readout, isA<ConductorUnavailableReadout>());
      expect(simulation.errorReason, ConductorMeasurementErrorReason.wrongPort);
      expect(simulation.continuityBeep, isFalse);
      expect(simulation.success, isFalse);
    });

    test(
      '$kind powered precedes missing probes in errors but readout is OL',
      () {
        final simulation = _snapshot(
          kind: kind,
          mode: mode,
          powered: true,
          red: WirePoint.none,
        );
        expect(simulation.readout, isA<ConductorOpenLoopReadout>());
        expect(simulation.errorReason, ConductorMeasurementErrorReason.powered);
        expect(simulation.unsafeOhmicMeasurement, isFalse);
        expect(simulation.continuityBeep, isFalse);
        expect(simulation.success, isFalse);
      },
    );

    for (final dangerMode in [
      MultimeterMode.resistance,
      MultimeterMode.continuity,
    ]) {
      test(
        '$kind powered $dangerMode danger precedes wrong exercise mode and port',
        () {
          final simulation = _snapshot(
            kind: kind,
            mode: dangerMode,
            port: MultimeterPort.current,
            powered: true,
          );
          expect(simulation.unsafeOhmicMeasurement, isTrue);
          expect(simulation.readout, isA<ConductorWarningReadout>());
          expect(
            simulation.errorReason,
            ConductorMeasurementErrorReason.unsafeOhmicMeasurement,
          );
          expect(simulation.correctSetup, isFalse);
          expect(simulation.success, isFalse);
          expect(simulation.continuityBeep, isFalse);
        },
      );
    }

    for (final broken in [false, true]) {
      test('$kind danger ignores same point and broken=$broken', () {
        final simulation = _snapshot(
          kind: kind,
          mode: mode,
          powered: true,
          broken: broken,
          black: WirePoint.pointA,
        );
        expect(simulation.probesConnected, isTrue);
        expect(simulation.probesAcrossWire, isFalse);
        expect(simulation.unsafeOhmicMeasurement, isTrue);
        expect(simulation.readout, isA<ConductorWarningReadout>());
        expect(
          simulation.errorReason,
          ConductorMeasurementErrorReason.unsafeOhmicMeasurement,
        );
        expect(simulation.continuityBeep, isFalse);
        expect(simulation.success, isFalse);
      });
    }

    for (final resistance in [50.0, 50.01]) {
      test(
        '$kind continuity raw threshold $resistance is independent of success',
        () {
          final simulation = _snapshot(
            kind: kind,
            mode: MultimeterMode.continuity,
            resistance: resistance,
          );
          expect(simulation.readout, _numeric(resistance));
          expect(simulation.continuityBeep, resistance == 50.0);
          expect(simulation.correctSetup, continuity);
          expect(simulation.success, continuity);
          expect(
            simulation.errorReason,
            continuity
                ? ConductorMeasurementErrorReason.incorrectSetup
                : ConductorMeasurementErrorReason.wrongMode,
          );
        },
      );
    }
  }

  test(
    'beep requires a valid continuity connection, not just low resistance',
    () {
      for (final simulation in [
        _snapshot(mode: MultimeterMode.continuity, broken: true),
        _snapshot(mode: MultimeterMode.continuity, powered: true),
        _snapshot(
          mode: MultimeterMode.continuity,
          port: MultimeterPort.current,
        ),
        _snapshot(mode: MultimeterMode.continuity, red: WirePoint.none),
        _snapshot(mode: MultimeterMode.continuity, black: WirePoint.none),
      ]) {
        expect(simulation.continuityBeep, isFalse);
      }
    },
  );
}
