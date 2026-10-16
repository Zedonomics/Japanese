import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kana_path/app_controller.dart';
import 'package:kana_path/domain/domain.dart';
import 'package:kana_path/main.dart' as app;
import 'package:kana_path/ui/drawing_pad.dart';
import 'package:kana_path/ui/kana_path_app.dart';
import 'package:kana_path/ui/lesson_screen.dart';
import 'package:kana_path/ui/ui_contract.dart';

Future<void> waitUntil(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'Native app startup or storage operation did not finish in 30 seconds.',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native startup, saved answer, and model-independent drawing input', (
    tester,
  ) async {
    debugPrint('Native smoke: startup begin.');
    app.main();
    await tester.pump();
    final controller =
        tester.widget<KanaPathApp>(find.byType(KanaPathApp)).controller
            as AppController;
    addTearDown(() async {
      debugPrint('Native smoke: teardown begin.');
      await controller.close().timeout(const Duration(seconds: 10));
      debugPrint('Native smoke: teardown complete.');
    });
    await waitUntil(tester, () => !controller.loading);
    expect(controller.error, isNull);
    expect(controller.curriculum.length, 311);
    expect(find.text('Kana Path'), findsOneWidget);
    debugPrint('Native smoke: startup complete.');

    // This test uses the real native SQLite database. Use a dedicated simulator
    // or test install, not the phone installation containing personal progress.
    debugPrint('Native smoke: reading lesson setup begin.');
    await controller.abandonLesson();
    await controller.startLesson(LessonScope.hiragana, LessonFocus.reading);
    debugPrint('Native smoke: reading lesson setup complete.');
    debugPrint('Native smoke: reading introduction save begin.');
    controller.completeIntroduction();
    await waitUntil(tester, () => !controller.busy);
    debugPrint('Native smoke: reading introduction saved.');
    final resume = find.text('Pick up where you left off');
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.byType(LessonScreen), findsOneWidget);
    final question = controller.activeSession!.currentQuestion!;
    final item = controller.curriculum.firstWhere(
      (i) => i.id == question.itemId,
    );
    final answer = question.expectedAnswerFor(item);
    await tester.enterText(find.byType(TextField), answer);
    // Text entry schedules the rebuild that enables Check answer. Wait for
    // that frame before tapping, just as a person does on a real keyboard.
    await tester.pump();
    final check = find.text('Check answer');
    await tester.ensureVisible(check);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Check answer'),
          )
          .onPressed,
      isNotNull,
    );
    debugPrint('Native smoke: reading answer submission begin.');
    await tester.tap(check);
    await waitUntil(
      tester,
      () => controller.feedback != null || controller.error != null,
    );
    expect(controller.error, isNull);
    expect(controller.feedback!.outcome, ReviewOutcome.correct);
    expect(controller.activeSession!.currentIndex, 0);
    expect(
      controller.progress[SkillProgress.keyFor(item.id, question.skill)],
      isNotNull,
    );
    debugPrint('Native smoke: reading answer feedback saved.');

    // Switch to a drawing question without ever downloading a recognition model.
    debugPrint('Native smoke: drawing lesson setup begin.');
    await controller.abandonLesson();
    await controller.startLesson(LessonScope.hiragana, LessonFocus.drawing);
    debugPrint('Native smoke: drawing lesson setup complete.');
    debugPrint('Native smoke: drawing introduction save begin.');
    controller.completeIntroduction();
    await waitUntil(tester, () => !controller.busy);
    debugPrint('Native smoke: drawing introduction saved.');
    // The open lesson route reacts to the controller's replacement session.
    expect(find.byType(LessonScreen), findsOneWidget);
    if (controller.modelStatus == HandwritingModelStatus.ready) {
      expect(find.byType(DrawingPad), findsOneWidget);
    } else {
      expect(find.text('Download model'), findsOneWidget);
    }

    // Exercise the same production canvas offline regardless of model readiness.
    // This validates touch capture and coordinates, not native recognition.
    debugPrint('Native smoke: drawing canvas check begin.');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DrawingPad(cells: 1, enabled: true, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    final canvas = find.byKey(const ValueKey('handwriting-canvas'));
    await tester.drag(canvas, const Offset(60, 50));
    await tester.pump();
    final state = tester.state<DrawingPadState>(find.byType(DrawingPad));
    expect(state.submission.strokes, isNotEmpty);
    expect(state.submission.width, greaterThan(0));
    expect(state.submission.height, greaterThan(0));
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(state.submission.strokes, isEmpty);
    expect(tester.takeException(), isNull);
    debugPrint('Native smoke: drawing canvas check complete.');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
