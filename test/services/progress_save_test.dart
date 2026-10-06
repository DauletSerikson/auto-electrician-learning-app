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
  });
  tearDown(() => platform.uninstall());

  test('successful platform write survives cache recreation', () async {
    await ProgressService().completeLesson('a');
    SharedPreferences.resetStatic();
    expect(await ProgressService().getCompletedLessons(), {'a'});
  });

  for (final throws in [false, true]) {
    test(
      'failed write throws and never appears as persisted completion: $throws',
      () async {
        platform.values['flutter.completed_lessons'] = ['existing'];
        platform.onWrite = () async {
          if (throws) throw PlatformException(code: 'write_failed');
          return false;
        };
        await expectLater(
          ProgressService().completeLesson('a'),
          throws ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        expect(await ProgressService().getCompletedLessons(), {'existing'});
        platform.onWrite = null;
        await ProgressService().completeLesson('b');
        expect(await ProgressService().getCompletedLessons(), {
          'existing',
          'b',
        });
      },
    );
  }
}
