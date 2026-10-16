import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/ui/drawing_pad.dart';

class _Harness {
  final pad = GlobalKey<DrawingPadState>();
  final scroll = ScrollController(initialScrollOffset: 120);
  final enabled = ValueNotifier(true);
  final changes = <bool>[];

  Finder get canvas => find.byKey(const ValueKey('handwriting-canvas'));

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(scroll.dispose);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 220, width: double.infinity),
                ValueListenableBuilder(
                  valueListenable: enabled,
                  builder: (context, value, _) => DrawingPad(
                    key: pad,
                    cells: 1,
                    enabled: value,
                    onChanged: changes.add,
                  ),
                ),
                const SizedBox(height: 900, width: double.infinity),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(scroll.offset, 120);
  }
}

void main() {
  testWidgets('vertical ink owns its gesture inside a scrolling lesson', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final origin = tester.getTopLeft(harness.canvas);
    const points = [
      Offset(120, 200),
      Offset(120, 196),
      Offset(120, 190),
      Offset(120, 180),
      Offset(120, 170),
      Offset(120, 160),
      Offset(120, 110),
    ];
    final gesture = await tester.startGesture(origin + points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(origin + point);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, 120);
    final ink = harness.pad.currentState!.submission;
    expect(ink.strokes, hasLength(1));
    expect(
      ink.strokes.single.points.map((point) => Offset(point.x, point.y)),
      orderedEquals(points),
    );
    expect(harness.changes, [true]);
  });

  for (final direction in {
    'downward': const Offset(0, 10),
    'horizontal': const Offset(10, 0),
    'diagonal': const Offset(10, 10),
  }.entries) {
    testWidgets(
      '${direction.key} strokes preserve their first small movements',
      (tester) async {
        final harness = _Harness();
        await harness.pump(tester);
        final origin = tester.getTopLeft(harness.canvas);
        const start = Offset(80, 80);
        final points = [
          start,
          start + direction.value * .3,
          start + direction.value,
          start + direction.value * 2,
          start + direction.value * 6,
        ];
        final gesture = await tester.startGesture(origin + points.first);
        for (final point in points.skip(1)) {
          await gesture.moveTo(origin + point);
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(harness.scroll.offset, 120);
        final stroke = harness.pad.currentState!.submission.strokes.single;
        expect(
          stroke.points.map((point) => Offset(point.x, point.y)),
          orderedEquals(points),
        );
        expect(
          stroke.points.map((point) => point.milliseconds),
          orderedEquals(
            stroke.points.map((point) => point.milliseconds).toList()..sort(),
          ),
        );
      },
    );
  }

  testWidgets('a tap records a dot without scrolling', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);
    final origin = tester.getTopLeft(harness.canvas);
    await tester.tapAt(origin + const Offset(50, 70));
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, 120);
    final dot = harness.pad.currentState!.submission.strokes.single.points;
    expect(dot, hasLength(1));
    expect(Offset(dot.single.x, dot.single.y), const Offset(50, 70));
    expect(harness.changes, [true]);
  });

  testWidgets('the lesson still scrolls outside its writing cells', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await tester.dragFrom(const Offset(20, 300), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, greaterThan(120));
    expect(harness.pad.currentState!.submission.strokes, isEmpty);
    expect(harness.changes, isEmpty);
  });

  testWidgets('disabled writing cells permit scrolling without adding ink', (
    tester,
  ) async {
    final harness = _Harness();
    harness.enabled.value = false;
    await harness.pump(tester);
    await tester.drag(harness.canvas, const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, greaterThan(120));
    expect(harness.pad.currentState!.submission.strokes, isEmpty);
    expect(harness.changes, isEmpty);
  });

  testWidgets('a second finger cannot change or finish the active stroke', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final origin = tester.getTopLeft(harness.canvas);
    final first = await tester.startGesture(
      origin + const Offset(80, 80),
      pointer: 1,
    );
    await first.moveTo(origin + const Offset(80, 85));
    final second = await tester.startGesture(
      origin + const Offset(200, 200),
      pointer: 2,
    );
    await second.moveTo(origin + const Offset(230, 220));
    await first.moveTo(origin + const Offset(80, 130));
    await second.up();
    expect(harness.pad.currentState!.submission.strokes, isEmpty);
    expect(harness.changes, isEmpty);
    await first.up();
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, 120);
    expect(
      harness.pad.currentState!.submission.strokes.single.points.map(
        (point) => Offset(point.x, point.y),
      ),
      orderedEquals([
        const Offset(80, 80),
        const Offset(80, 85),
        const Offset(80, 130),
      ]),
    );
    expect(harness.changes, [true]);
  });

  testWidgets('canceling a stroke discards it and permits a fresh stroke', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final origin = tester.getTopLeft(harness.canvas);
    final canceled = await tester.startGesture(origin + const Offset(80, 80));
    await canceled.moveTo(origin + const Offset(80, 140));
    await canceled.cancel();
    await tester.pump();
    expect(harness.pad.currentState!.submission.strokes, isEmpty);
    expect(harness.changes, isEmpty);

    await tester.tapAt(origin + const Offset(120, 120));
    await tester.pumpAndSettle();
    expect(harness.scroll.offset, 120);
    expect(
      harness.pad.currentState!.submission.strokes.single.points,
      hasLength(1),
    );
    expect(harness.changes, [true]);
  });

  testWidgets('disabling during a stroke discards only the unfinished ink', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final origin = tester.getTopLeft(harness.canvas);
    await tester.tapAt(origin + const Offset(50, 50));
    final interrupted = await tester.startGesture(
      origin + const Offset(80, 80),
    );
    await interrupted.moveTo(origin + const Offset(80, 140));
    harness.enabled.value = false;
    await tester.pump();
    harness.enabled.value = true;
    await tester.pump();
    await interrupted.moveTo(origin + const Offset(80, 170));
    await interrupted.up();
    await tester.tapAt(origin + const Offset(120, 120));
    await tester.pumpAndSettle();

    expect(harness.pad.currentState!.submission.strokes, hasLength(2));
    expect(harness.changes, [true, true]);
    expect(harness.scroll.offset, 120);
  });
}
