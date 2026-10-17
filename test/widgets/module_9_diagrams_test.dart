import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _allSizes = {
  'battery_structure': Size(960, 1608),
  'battery_test_context': Size(960, 1665),
  'starter_power': Size(960, 2394),
  'starter_control': Size(960, 2400),
  'starter_drop_points': Size(960, 1827),
  'alternator_structure': Size(960, 1938),
  'charging_power': Size(960, 2388),
  'charging_control': Size(960, 1836),
  'battery_pulse': Size(960, 1686),
  'sleep_profiles': Size(960, 1692),
  'wake_profile': Size(960, 1800),
  'parasitic_search': Size(960, 1854),
  'parasitic_branches': Size(960, 1878),
  'wake_network': Size(960, 1752),
  'meter_current_safety': Size(960, 1665),
};

Future<Lesson> _load(int order) => CourseService().loadLesson(
  'assets/course/stage_8/lesson_${order.toString().padLeft(2, '0')}.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);
  setUpAll(() async {
    final previewFont = Platform.environment['R12_PREVIEW_FONT'];
    if (previewFont != null) {
      await ui.loadFontFromList(
        await File(previewFont).readAsBytes(),
        fontFamily: 'Roboto',
      );
      final fallbackFont = Platform.environment['R12_PREVIEW_SYMBOL_FONT'];
      if (fallbackFont != null) {
        await ui.loadFontFromList(
          await File(fallbackFont).readAsBytes(),
          fontFamily: 'R12PreviewSymbols',
        );
      }
    }
  });

  testWidgets(
    'every PNG is bundled and decodes at the authored 3x dimensions',
    (tester) async {
      await tester.runAsync(() async {
        for (final entry in _allSizes.entries) {
          final source = File(
            'assets/images/starting_charging/source/${entry.key}.svg',
          );
          expect(await source.exists(), isTrue);
          expect(await source.readAsString(), contains('viewBox="0 0 320 '));
          expect(
            await File('assets/images/starting_charging/README.md')
                .readAsString(),
            contains('`${entry.key}`'),
          );
          final bytes = await rootBundle.load(
            'assets/images/starting_charging/${entry.key}.png',
          );
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, entry.value.width.toInt());
          expect(frame.image.height, entry.value.height.toInt());
          frame.image.dispose();
          codec.dispose();
        }
      });
    },
  );

  for (final width in [320.0, 360.0]) {
    for (final dark in [false, true]) {
      testWidgets('image renderer fits $width px, dark=$dark, text scale 1.3', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1050));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundaryKey = GlobalKey();
        final seen = <String>{};
        for (final order in List.generate(10, (i) => i + 1)) {
          final lesson = await _load(order);
          for (final block in lesson.blocks.whereType<ImageLessonBlock>()) {
            if (!_allSizes.containsKey(
                  block.asset.split('/').last.replaceAll('.png', ''),
                ) ||
                !seen.add(block.asset)) {
              continue;
            }
            // Start decoding in real async before mounting Image; otherwise
            // a pending fake-async image request can stall precaching.
            await tester.runAsync(() async {
              final stream = AssetImage(block.asset)
                  .resolve(ImageConfiguration.empty);
              final ready = Completer<void>();
              final listener = ImageStreamListener(
                (_, _) => ready.complete(),
                onError: (Object error, StackTrace? stack) =>
                    ready.completeError(error, stack),
              );
              stream.addListener(listener);
              try {
                await ready.future.timeout(const Duration(seconds: 15));
              } finally {
                stream.removeListener(listener);
              }
            });
            final theme = dark ? AppTheme.dark : AppTheme.light;
            // The headless test engine has no Android system font fallback.
            // Only optional review captures supply a local symbol font.
            final previewTheme =
                Platform.environment['R12_PREVIEW_SYMBOL_FONT'] == null
                ? theme
                : theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamilyFallback: ['R12PreviewSymbols'],
                    ),
                  );
            await tester.pumpWidget(
              MaterialApp(
                theme: previewTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1050),
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: ColoredBox(
                          color: (dark ? AppTheme.dark : AppTheme.light)
                              .scaffoldBackgroundColor,
                          child: Padding(
                            // Matches the existing LessonScreen ListView padding.
                            padding: const EdgeInsets.all(20),
                            child: LessonBlockRenderer(
                              block: block,
                              blockIndex: 0,
                              onAnswered: (_) {},
                              onRetry: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final image = tester.getRect(find.byType(Image));
            final stem = block.asset.split('/').last.replaceAll('.png', '');
            final sourceSize = _allSizes[stem]!;
            expect(image.width, closeTo(width - 40, 0.01));
            expect(
              image.height,
              closeTo(image.width * sourceSize.height / sourceSize.width, 0.01),
            );
            expect(image.left, 20);
            expect(image.right, width - 20);
            expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
            expect(
              tester.getRect(find.text(block.caption)).top,
              greaterThanOrEqualTo(image.bottom),
            );
            // Optional, reviewable captures of the actual production renderer.
            // Ordinary test runs do not write artifacts or golden baselines.
            if (Platform.environment['SAVE_R12_MODULE9_PREVIEWS'] == '1' &&
                width == 360) {
              await tester.runAsync(() async {
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final capture = await boundary.toImage();
                final bytes = await capture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final output = File(
                  'docs/verification/r12_module9/${stem}_${dark ? 'dark' : 'light'}_360.png',
                );
                await output.parent.create(recursive: true);
                await output.writeAsBytes(
                  bytes!.buffer.asUint8List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes,
                  ),
                );
                capture.dispose();
              });
            }
          }
        }
      });
    }
  }
}
