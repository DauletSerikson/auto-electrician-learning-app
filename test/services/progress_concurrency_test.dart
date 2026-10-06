import 'dart:async';

import 'package:electrician/services/progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_platform_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferencesPlatformFake platform;
  setUp(() {
    platform = PreferencesPlatformFake()..install();
    platform.values['flutter.completed_lessons'] = ['existing'];
  });
  tearDown(() => platform.uninstall());

  for (final separateInstances in [false, true]) {
    test(
      'delayed concurrent writes retain both IDs, separate instances: $separateInstances',
      () async {
        final started = Completer<void>();
        final release = Completer<bool>();
        platform.onWrite = () {
          if (platform.writes == 1) {
            started.complete();
            return release.future;
          }
          return Future.value(true);
        };
        final firstService = ProgressService();
        final secondService = separateInstances
            ? ProgressService()
            : firstService;
        final first = firstService.completeLesson('a');
        final second = secondService.completeLesson('b');
        await started.future;
        await Future<void>.delayed(Duration.zero);
        final writesWhileFirstPending = platform.writes;
        release.complete(true);
        await Future.wait([first, second]);
        expect(writesWhileFirstPending, 1);
        SharedPreferences.resetStatic();
        expect(await ProgressService().getCompletedLessons(), {
          'existing',
          'a',
          'b',
        });
      },
    );
  }

  for (final throws in [false, true]) {
    test(
      'failed first write does not poison queued second write: $throws',
      () async {
        final started = Completer<void>();
        final release = Completer<bool>();
        platform.onWrite = () {
          if (platform.writes == 1) {
            started.complete();
            return release.future;
          }
          return Future.value(true);
        };
        final first = ProgressService().completeLesson('failed');
        final failure = expectLater(
          first,
          throws ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        final second = ProgressService().completeLesson('b');
        await started.future;
        if (throws) {
          release.completeError(PlatformException(code: 'write_failed'));
        } else {
          release.complete(false);
        }
        await failure;
        await second;
        expect(await ProgressService().getCompletedLessons(), {
          'existing',
          'b',
        });
        expect(platform.writes, 2);
      },
    );
  }

  test('failed read in first request leaves queue usable', () async {
    var reads = 0;
    platform.onRead = () async {
      if (++reads == 1) throw PlatformException(code: 'read_failed');
    };
    final first = expectLater(
      ProgressService().completeLesson('failed'),
      throwsA(isA<PlatformException>()),
    );
    final second = ProgressService().completeLesson('b');
    await first;
    await second;
    expect(await ProgressService().getCompletedLessons(), {'existing', 'b'});
  });

  test('same-ID concurrent completions are logically idempotent', () async {
    await Future.wait([
      ProgressService().completeLesson('a'),
      ProgressService().completeLesson('a'),
    ]);
    expect(await ProgressService().getCompletedLessons(), {'existing', 'a'});
    expect(platform.values['flutter.completed_lessons'], hasLength(2));
  });

  test(
    'middle failed request does not lose preceding or following success',
    () async {
      platform.onWrite = () async => platform.writes != 2;
      final first = ProgressService().completeLesson('a');
      final failed = expectLater(
        ProgressService().completeLesson('failed'),
        throwsStateError,
      );
      final third = ProgressService().completeLesson('c');
      await Future.wait([first, failed, third]);
      expect(await ProgressService().getCompletedLessons(), {
        'existing',
        'a',
        'c',
      });
    },
  );

  test('batch from multiple instances retains every completed ID', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++)
        ProgressService().completeLesson('lesson_$i'),
    ]);
    SharedPreferences.resetStatic();
    expect(await ProgressService().getCompletedLessons(), {
      'existing',
      for (var i = 0; i < 10; i++) 'lesson_$i',
    });
  });
}
