import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/module_12_content_test.dart' show loadBody;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);
  final sizes = (jsonDecode(
    File('assets/images/body_electronics/source/catalog.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>);
  setUpAll(() async {
    final font = Platform.environment['R15_MODULE_FONT'];
    if (font != null) {
      await ui.loadFontFromList(
        await File(font).readAsBytes(),
        fontFamily: 'Roboto',
      );
    }
  });

  testWidgets(
    'all 16 PNGs bundled at 3x source sizes without runtime SVG references',
    (tester) async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets().any(
          (a) => a.startsWith('assets/images/body_electronics/source/'),
        ),
        isFalse,
      );
      await tester.runAsync(() async {
        for (final entry in sizes.entries) {
          final codec = await ui.instantiateImageCodec(
            (await rootBundle.load(
              'assets/images/body_electronics/${entry.key}.png',
            )).buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, entry.value[0]);
          expect(frame.image.height, entry.value[1]);
          expect(
            File('assets/images/body_electronics/source/${entry.key}.svg')
                .readAsStringSync(),
            contains('viewBox="0 0 320 '),
          );
          frame.image.dispose();
          codec.dispose();
        }
      });
      expect(sizes, hasLength(16));
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'all diagrams and captions readable layout at 360px scale 1.3 dark=$dark',
      (tester) async {
        final capture = Platform.environment['SAVE_R15_MODULE_PREVIEWS'] == '1';
        await tester.binding.setSurfaceSize(Size(360, capture ? 5000 : 1050));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final seen = <String>{};
        for (var order = 1; order <= 10; order++) {
          final lesson = (await tester.runAsync(() => loadBody(order)))!;
          for (final block in lesson.blocks.whereType<ImageLessonBlock>()) {
            if (!seen.add(block.asset)) continue;
            await tester.runAsync(() async {
              final stream = AssetImage(block.asset)
                  .resolve(ImageConfiguration.empty);
              final done = Completer<void>();
              final listener = ImageStreamListener(
                (_, _) => done.complete(),
                onError: (Object e, StackTrace? s) => done.completeError(e, s),
              );
              stream.addListener(listener);
              try {
                await done.future.timeout(const Duration(seconds: 15));
              } finally {
                stream.removeListener(listener);
              }
            });
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(360, 1050),
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: RepaintBoundary(
                        key: key,
                        child: ColoredBox(
                          color: (dark ? AppTheme.dark : AppTheme.light)
                              .scaffoldBackgroundColor,
                          child: Padding(
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
            expect(tester.takeException(), isNull, reason: block.asset);
            final imageRect = tester.getRect(find.byType(Image));
            expect(imageRect.width, 320);
            expect(imageRect.left, 20);
            expect(imageRect.right, 340);
            expect(
              tester.getRect(find.text(block.caption)).top,
              greaterThanOrEqualTo(imageRect.bottom),
            );
            if (capture) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final stem = block.asset.split('/').last.replaceAll('.png', '');
                final file = File(
                  'build/r15_module12_previews/${stem}_${dark ? 'dark' : 'light'}_360.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
        }
        expect(seen, hasLength(16));
      },
    );
  }
}
