import 'dart:ui' as ui;

import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real safety lesson loads and renders approved battery artwork', (
    tester,
  ) async {
    final lesson = await CourseService().loadLesson(
      'assets/course/stage_0/lesson_02.json',
    );
    final block = lesson.blocks.whereType<ImageLessonBlock>().single;
    expect(block.asset, 'assets/images/automotive_12v_battery.png');
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(block.asset);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 887);
      expect(frame.image.height, 887);
      frame.image.dispose();
      codec.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LessonBlockRenderer(
              block: block,
              blockIndex: 1,
              onAnswered: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      AssetImage(block.asset),
    );
    expect(find.text('Автомобильный аккумулятор'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
