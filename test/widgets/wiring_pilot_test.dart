import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _lessons = [2, 4, 5];
const _sizes = {
  'symbols_lamp': Size(960, 1428),
  'symbols_junction': Size(960, 1605),
  'relay_off': Size(960, 2205),
  'relay_on': Size(960, 2205),
  'connector_page_1': Size(960, 1440),
  'connector_page_2': Size(960, 1440),
  'connector_views': Size(960, 1605),
};

Future<Lesson> _load(int order) => CourseService().loadLesson(
  'assets/course/stage_4/lesson_${order.toString().padLeft(2, '0')}.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);
  setUpAll(() async {
    final previewFont = Platform.environment['R8_PREVIEW_FONT'];
    if (previewFont != null) {
      await ui.loadFontFromList(
        await File(previewFont).readAsBytes(),
        fontFamily: 'Roboto',
      );
    }
  });

  test(
    'pilot slices parse without changing the published 32-lesson course',
    () async {
      expect(await CourseService().loadAllLessons(), hasLength(32));
      final assets = <String>{};
      for (final order in _lessons) {
        final lesson = await _load(order);
        expect(lesson.id, 'wiring_${order.toString().padLeft(2, '0')}');
        expect(lesson.moduleId, 'stage_4');
        expect(lesson.order, order);
        expect(lesson.completion.isQuiz, isFalse);
        final images = lesson.blocks.whereType<ImageLessonBlock>().toList();
        expect(images, hasLength(order == 5 ? 3 : 2));
        final tasks = <int, bool>{};
        for (var i = 0; i < lesson.blocks.length; i++) {
          switch (lesson.blocks[i]) {
            case ImageLessonBlock(:final asset, :final caption):
              expect(assets.add(asset), isTrue);
              expect(caption.trim(), isNotEmpty);
              // Every drawing must have a reading task before the next drawing.
              expect(
                lesson.blocks
                    .skip(i + 1)
                    .takeWhile((b) => b is! ImageLessonBlock)
                    .whereType<QuestionLessonBlock>(),
                isNotEmpty,
              );
            case QuestionLessonBlock(
              :final answers,
              :final correctAnswer,
              :final explanation,
            ):
              expect(answers.toSet(), hasLength(answers.length));
              expect(correctAnswer, inInclusiveRange(0, answers.length - 1));
              expect(explanation.trim(), isNotEmpty);
              tasks[i] = true;
            default:
              expect(isScoredLessonBlock(lesson.blocks[i]), isFalse);
          }
        }
        expect(tasks, hasLength(4));
        expect(evaluateLessonAttempt(lesson, {}).canComplete, isFalse);
        expect(evaluateLessonAttempt(lesson, tasks).canComplete, isTrue);
        tasks[tasks.keys.first] = false;
        expect(evaluateLessonAttempt(lesson, tasks).canComplete, isFalse);
      }
      expect(
        assets.map((p) => p.split('/').last.replaceAll('.png', '')).toSet(),
        _sizes.keys.toSet(),
      );
    },
  );

  testWidgets(
    'every PNG is bundled and decodes at the authored 3x dimensions',
    (tester) async {
      await tester.runAsync(() async {
        for (final entry in _sizes.entries) {
          final bytes = await rootBundle.load(
            'assets/images/wiring/${entry.key}.png',
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
        for (final order in _lessons) {
          final lesson = await _load(order);
          for (final block in lesson.blocks.whereType<ImageLessonBlock>()) {
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
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
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
            final sourceSize = _sizes[stem]!;
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
            if (Platform.environment['SAVE_R8_PREVIEWS'] == '1' &&
                width == 360 &&
                (!dark || stem == 'relay_on')) {
              await tester.runAsync(() async {
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final capture = await boundary.toImage();
                final bytes = await capture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final output = File(
                  'docs/verification/r8_pilot/${stem}_${dark ? 'dark' : 'light'}_360.png',
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

  testWidgets(
    'real pilot reading task reports wrong answer then retry then correct',
    (tester) async {
      final lesson = await _load(4);
      final block = lesson.blocks.whereType<QuestionLessonBlock>().first;
      final results = <bool>[];
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonBlockRenderer(
                block: block,
                blockIndex: 0,
                onAnswered: results.add,
                onRetry: () => retries++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(block.answers[0]));
      await tester.pump();
      await tester.tap(find.text('Проверить'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      final retry = find.text('Попробовать ещё раз');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retries, 1);
      await tester.tap(find.text(block.answers[block.correctAnswer]));
      await tester.pump();
      await tester.tap(find.text('Проверить'));
      await tester.pumpAndSettle();
      expect(results, [false, true]);
      expect(find.text(block.explanation), findsOneWidget);
    },
  );
}
