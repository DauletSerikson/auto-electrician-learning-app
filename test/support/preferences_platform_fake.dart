import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the actual plugin cache and platform boundary without a new DI layer.
class PreferencesPlatformFake {
  final Map<String, Object> values = {};
  int writes = 0;
  Future<bool> Function()? onWrite;
  Future<void> Function()? onRead;

  void install() {
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            switch (call.method) {
              case 'getAll':
                await onRead?.call();
                return Map<String, Object>.from(values);
              case 'setStringList':
                writes++;
                final saved = await (onWrite?.call() ?? Future.value(true));
                if (saved) {
                  final args = call.arguments as Map;
                  values[args['key'] as String] = List<String>.from(
                    args['value'] as List,
                  );
                }
                return saved;
              default:
                throw StateError(
                  'Unexpected preference method: ${call.method}',
                );
            }
          },
        );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
    SharedPreferences.resetStatic();
  }
}
