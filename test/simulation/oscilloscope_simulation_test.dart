import 'dart:math' as math;

import 'package:electrician/simulation/oscilloscope_simulation.dart';
import 'package:electrician/simulation/scope_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const simulation = OscilloscopeSimulation();
  final sine = SineScopeSignal(amplitude: 4, offset: 1, frequencyHz: 100);
  final pulse = ScopeScenario.pwm30.signal as PulseScopeSignal;

  test('sine amplitude offset period and quarter-cycle voltages', () {
    expect(sine.minimum, -3);
    expect(sine.maximum, 5);
    expect(sine.periodSeconds, .01);
    expect(sine.voltageAt(0), 1);
    expect(sine.voltageAt(.0025), closeTo(5, 1e-12));
    expect(sine.voltageAt(.0075), closeTo(-3, 1e-12));
  });

  for (final scenario in [
    ScopeScenario.sine,
    ScopeScenario.square,
    ScopeScenario.pwm30,
    ScopeScenario.pwm60,
  ]) {
    test('$scenario is periodic away from and at defined phase positions', () {
      final signal = scenario.signal as PeriodicScopeSignal;
      for (final fraction in [.05, .2, .45, .7, .9]) {
        final voltage = signal.voltageAt(fraction * signal.periodSeconds);
        for (var i = 1; i < 15; i++) {
          expect(
            signal.voltageAt((fraction + i) * signal.periodSeconds),
            closeTo(voltage, 1e-10),
          );
        }
      }
      expect(signal.frequencyHz * signal.periodSeconds, 1);
    });
  }

  test('PWM high time and mean differ at identical frequency', () {
    final other = ScopeScenario.pwm60.signal as PulseScopeSignal;
    expect(pulse.periodSeconds, .01);
    expect(pulse.highSeconds, .003);
    expect(pulse.averageVoltage, 1.5);
    expect(other.periodSeconds, pulse.periodSeconds);
    expect(other.highSeconds, .006);
    expect(other.averageVoltage, 3);
    expect(pulse.voltageAt(.002), 5);
    expect(pulse.voltageAt(.004), 0);
    expect(other.voltageAt(.004), 5);
  });

  test(
    'pulse boundary values agree with exact generated edges over the record',
    () {
      for (var cycle = 0; cycle < 20; cycle++) {
        final start = cycle * pulse.periodSeconds;
        final end = start + pulse.highSeconds;
        expect(pulse.voltageAt(start), pulse.high, reason: 'rising $cycle');
        expect(pulse.voltageAt(end), pulse.low, reason: 'falling $cycle');
        expect(pulse.voltageAt(end - 1e-8), pulse.high);
        expect(pulse.voltageAt(end + 1e-8), pulse.low);
      }
      final missing =
          ScopeScenario.missingPulse.signal as MissingPulseScopeSignal;
      expect(missing.voltageAt(missing.eventEnd), 0);
    },
  );

  test('constant has no crossing, including equality with level', () {
    final constant = ConstantScopeSignal(2.5);
    for (final level in [0.0, 2.5, 6.0]) {
      for (final edge in ScopeEdge.values) {
        expect(constant.crossings(level, edge, .2), isEmpty);
      }
    }
    expect(constant.voltageAt(.1), 2.5);
    expect(constant, isNot(isA<PeriodicScopeSignal>()));
  });

  test(
    'missing pulse suppresses both edges without becoming a periodic record',
    () {
      final missing =
          ScopeScenario.missingPulse.signal as MissingPulseScopeSignal;
      expect(missing, isNot(isA<PeriodicScopeSignal>()));
      expect(missing.eventStart, .02);
      expect(missing.eventEnd, .023);
      expect(missing.voltageAt(.021), 0);
      expect(missing.voltageAt(.011), 5);
      expect(missing.voltageAt(.031), 5);
      expect(
        missing.crossings(2.5, ScopeEdge.rising, .2),
        isNot(contains(.02)),
      );
      expect(
        missing.crossings(2.5, ScopeEdge.falling, .2),
        isNot(contains(.023)),
      );
      expect(missing.crossings(2.5, ScopeEdge.rising, .2), contains(.03));
    },
  );

  test(
    'analytic sine crossings have the requested direction and exact level',
    () {
      for (final edge in ScopeEdge.values) {
        final times = sine.crossings(2.0, edge, .2);
        expect(times, isNotEmpty);
        for (final time in times) {
          expect(sine.voltageAt(time), closeTo(2, 1e-10));
          final delta =
              sine.voltageAt(time + 1e-7) - sine.voltageAt(time - 1e-7);
          expect(delta.sign, edge == ScopeEdge.rising ? 1 : -1);
        }
      }
      final first = sine.crossings(2, ScopeEdge.rising, .2).first;
      expect(first, closeTo(math.asin(.25) / (2 * math.pi * 100), 1e-12));
    },
  );

  test(
    'sine extrema, out of range and nonfinite levels do not falsely trigger',
    () {
      for (final level in [-4.0, -3.0, 5.0, 6.0, double.nan, double.infinity]) {
        for (final edge in ScopeEdge.values) {
          expect(sine.crossings(level, edge, .2), isEmpty);
        }
      }
    },
  );

  test('pulse edges use strict before/inclusive after and no event at record start', () {
    expect(pulse.crossings(2.5, ScopeEdge.rising, .035), [.01, .02, .03]);
    final falling = pulse.crossings(2.5, ScopeEdge.falling, .025);
    expect(falling.length, 3);
    expect(falling[0], closeTo(.003, 1e-12));
    expect(falling[1], closeTo(.013, 1e-12));
    expect(pulse.crossings(0, ScopeEdge.rising, .02), isEmpty);
    expect(pulse.crossings(5, ScopeEdge.falling, .02), isEmpty);
    expect(pulse.crossings(5, ScopeEdge.rising, .02), [.01, .02]);
    expect(pulse.crossings(0, ScopeEdge.falling, .02), hasLength(2));
  });

  test('voltage scale and center only transform display coordinates', () {
    final settings = ScopeSettings();
    final scaled = settings.copyWith(voltsPerDiv: 2, centerVoltage: 0);
    expect(settings.yFraction(2.5), .5);
    expect(scaled.yFraction(0), .5);
    expect(scaled.yFraction(8), 0);
    expect(scaled.yFraction(-8), 1);
    final before = simulation.capture(pulse, settings);
    final after = simulation.capture(pulse, scaled);
    expect(before.triggerSeconds, after.triggerSeconds);
    expect(
      before.points.map((p) => p.voltage),
      after.points.map((p) => p.voltage),
    );
    expect(pulse.highSeconds, .003);
    expect(pulse.minimum, 0);
    expect(pulse.maximum, 5);
  });

  test(
    'time scale changes window and projection without changing frequency',
    () {
      final a = ScopeSettings(millisecondsPerDiv: 2);
      final b = a.copyWith(millisecondsPerDiv: 4);
      expect(a.windowSeconds, .02);
      expect(b.windowSeconds, .04);
      expect(a.xFraction(.01, 0), .5);
      expect(b.xFraction(.01, 0), .25);
      expect(pulse.frequencyHz, 100);
    },
  );

  test(
    'capture uses first crossing with enough pre/post history and no wrap',
    () {
      final capture = simulation.capture(pulse, ScopeSettings());
      expect(capture.status, ScopeCaptureStatus.triggered);
      expect(capture.triggerSeconds, .01);
      expect(capture.startSeconds, closeTo(.002, 1e-12));
      expect(capture.points.first.seconds, capture.startSeconds);
      expect(capture.points.last.seconds, closeTo(.042, 1e-12));
      expect(
        capture.settings.xFraction(
          capture.triggerSeconds!,
          capture.startSeconds,
        ),
        closeTo(.2, 1e-12),
      );
      final longWindow = simulation.capture(
        pulse,
        ScopeSettings(millisecondsPerDiv: 10),
      );
      expect(longWindow.triggerSeconds, .02);
      expect(longWindow.startSeconds, closeTo(0, 1e-12));
      expect(longWindow.points.last.seconds, lessThanOrEqualTo(.2));
    },
  );

  test('direction switch selects falling event, independent of sampling', () {
    final capture = simulation.capture(
      pulse,
      ScopeSettings(edge: ScopeEdge.falling),
    );
    expect(capture.triggerSeconds, closeTo(.013, 1e-12));
    final narrow = PulseScopeSignal(
      low: 0,
      high: 5,
      duty: .0001,
      frequencyHz: 100,
    );
    final narrowCapture = simulation.capture(
      narrow,
      ScopeSettings(edge: ScopeEdge.falling),
    );
    expect(narrowCapture.triggerSeconds, closeTo(.010001, 1e-12));
    expect(narrowCapture.points.any((p) => p.voltage == 5), isTrue);
  });

  test('normal waits, auto honestly free-runs and single needs arming', () {
    final settings = ScopeSettings(triggerLevel: 6);
    final normal = simulation.capture(pulse, settings);
    expect(normal.status, ScopeCaptureStatus.waiting);
    expect(normal.points, isEmpty);
    expect(normal.triggerSeconds, isNull);
    final auto = simulation.capture(
      pulse,
      settings.copyWith(mode: ScopeTriggerMode.auto),
    );
    expect(auto.status, ScopeCaptureStatus.freeRunning);
    expect(auto.triggerSeconds, isNull);
    expect(auto.startSeconds, 0);
    expect(auto.points, isNotEmpty);
    final singleSettings = ScopeSettings(mode: ScopeTriggerMode.single);
    expect(
      simulation.capture(pulse, singleSettings).status,
      ScopeCaptureStatus.armed,
    );
    expect(
      simulation.capture(pulse, singleSettings, armSingle: true).status,
      ScopeCaptureStatus.triggered,
    );
    final noEvent = simulation.capture(
      pulse,
      settings.copyWith(mode: ScopeTriggerMode.single),
      armSingle: true,
    );
    expect(noEvent.status, ScopeCaptureStatus.armed);
    expect(noEvent.points, isEmpty);
  });

  test('auto with a real crossing is genuinely triggered', () {
    final capture = simulation.capture(
      pulse,
      ScopeSettings(mode: ScopeTriggerMode.auto),
    );
    expect(capture.status, ScopeCaptureStatus.triggered);
    expect(capture.triggerSeconds, .01);
  });

  test('trace preserves both sides of steps; missing pulse is not drawn', () {
    final capture = simulation.capture(
      ScopeScenario.missingPulse.signal,
      ScopeSettings(),
    );
    final step = capture.points
        .where((p) => (p.seconds - .01).abs() < 1e-12)
        .toList();
    expect(step.map((p) => p.voltage), [0, 5]);
    expect(
      capture.points
          .where((p) => p.seconds >= .02 && p.seconds < .023)
          .every((p) => p.voltage == 0),
      isTrue,
    );
    for (var i = 1; i < capture.points.length; i++) {
      expect(
        capture.points[i].seconds,
        greaterThanOrEqualTo(capture.points[i - 1].seconds),
      );
    }
  });

  test('captures are immutable and clipping is physical viewport clipping', () {
    final capture = simulation.capture(
      ScopeScenario.sine.signal,
      ScopeSettings(voltsPerDiv: .5, centerVoltage: 0),
    );
    expect(capture.clipped, isTrue);
    expect(() => capture.points.clear(), throwsUnsupportedError);
    final other = simulation.capture(
      ScopeScenario.sine.signal,
      ScopeSettings(voltsPerDiv: 2, centerVoltage: 0),
    );
    expect(other.clipped, isFalse);
    expect(capture.settings.voltsPerDiv, .5);
  });

  test(
    'settings task cannot be passed using a different signal or no capture',
    () {
      final capture = simulation.capture(pulse, ScopeSettings());
      expect(
        simulation.evaluate(
          exercise: ScopeExercise.trigger,
          target: ScopeScenario.square,
          selected: ScopeScenario.pwm30,
          capture: capture,
        ),
        isFalse,
      );
      expect(
        simulation.evaluate(
          exercise: ScopeExercise.trigger,
          target: ScopeScenario.pwm30,
          selected: ScopeScenario.pwm30,
          capture: simulation.capture(pulse, ScopeSettings(triggerLevel: 6)),
        ),
        isFalse,
      );
    },
  );

  test(
    'voltage task accepts a useful range, rejects clipping and tiny traces',
    () {
      bool check(double scale) => simulation.evaluate(
        exercise: ScopeExercise.voltageScale,
        target: ScopeScenario.sine,
        selected: ScopeScenario.sine,
        capture: simulation.capture(
          ScopeScenario.sine.signal,
          ScopeSettings(voltsPerDiv: scale, centerVoltage: 0),
        ),
      );
      expect(check(.5), isFalse);
      expect(
        check(1),
        isFalse,
      ); // Exactly full screen is outside the 50–90% requirement.
      expect(check(2), isTrue);
      expect(check(5), isFalse);
    },
  );

  test('time task counts complete visible periods, not just window/period', () {
    bool check(double scale) => simulation.evaluate(
      exercise: ScopeExercise.timeScale,
      target: ScopeScenario.square,
      selected: ScopeScenario.square,
      capture: simulation.capture(
        ScopeScenario.square.signal,
        ScopeSettings(millisecondsPerDiv: scale),
      ),
    );
    expect(check(1), isFalse);
    expect(
      check(2),
      isFalse,
    ); // Two periods wide but only one complete edge-to-edge interval.
    expect(check(4), isTrue);
    expect(check(10), isFalse);
  });

  test(
    'trigger task requires actual normal rising event and unclipped trace',
    () {
      for (final settings in [
        ScopeSettings(),
        ScopeSettings(mode: ScopeTriggerMode.auto),
        ScopeSettings(edge: ScopeEdge.falling),
        ScopeSettings(triggerLevel: 6),
        ScopeSettings(voltsPerDiv: .5),
      ]) {
        expect(
          simulation.evaluate(
            exercise: ScopeExercise.trigger,
            target: ScopeScenario.pwm30,
            selected: ScopeScenario.pwm30,
            capture: simulation.capture(pulse, settings),
          ),
          settings.mode == ScopeTriggerMode.normal &&
              settings.edge == ScopeEdge.rising &&
              settings.triggerLevel == 2.5 &&
              settings.voltsPerDiv == 1,
        );
      }
    },
  );

  test('reject invalid and nonfinite signal parameters', () {
    for (final frequency in [0.0, -1.0, 1001.0, double.nan, double.infinity]) {
      expect(
        () => SineScopeSignal(amplitude: 1, offset: 0, frequencyHz: frequency),
        throwsArgumentError,
      );
    }
    for (final duty in [0.0, 1.0, -0.1, double.nan]) {
      expect(
        () => PulseScopeSignal(low: 0, high: 5, duty: duty, frequencyHz: 100),
        throwsArgumentError,
      );
    }
    expect(() => ConstantScopeSignal(double.infinity), throwsArgumentError);
    expect(
      () => SineScopeSignal(amplitude: 0, offset: 0, frequencyHz: 100),
      throwsArgumentError,
    );
    expect(
      () => SineScopeSignal(amplitude: 4, offset: double.nan, frequencyHz: 100),
      throwsArgumentError,
    );
    expect(
      () => PulseScopeSignal(low: 5, high: 0, duty: .5, frequencyHz: 100),
      throwsArgumentError,
    );
    expect(
      () => MissingPulseScopeSignal(carrier: pulse, missingIndex: 0),
      throwsArgumentError,
    );
    expect(() => ScopeSettings(voltsPerDiv: double.nan), throwsArgumentError);
    expect(() => ScopeSettings(millisecondsPerDiv: 0), throwsArgumentError);
    expect(
      () => ScopeSettings(centerVoltage: double.infinity),
      throwsArgumentError,
    );
  });

  test('supported frequency boundaries remain finite and reproducible', () {
    for (final f in [1.0, 1000.0]) {
      final signal = SineScopeSignal(amplitude: 1, offset: 0, frequencyHz: f);
      final capture = simulation.capture(
        signal,
        ScopeSettings(mode: ScopeTriggerMode.auto),
      );
      expect(
        capture.points.every(
          (point) => point.voltage.isFinite && point.seconds.isFinite,
        ),
        isTrue,
      );
      expect(signal.voltageAt(signal.periodSeconds / 4), closeTo(1, 1e-12));
    }
  });
}
