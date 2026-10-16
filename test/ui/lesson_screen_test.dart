import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/domain/domain.dart';
import 'package:kana_path/ui/drawing_pad.dart';
import 'package:kana_path/ui/lesson_screen.dart';
import 'package:kana_path/ui/library_screen.dart';
import 'package:kana_path/ui/theme.dart';
import 'package:kana_path/ui/ui_contract.dart';

const item = LearningItem(
  id: 'hira-a',
  script: ScriptKind.hiragana,
  glyph: 'あ',
  romaji: 'a',
);

class _Controller extends LearningController {
  _Controller({PracticeSkill skill = PracticeSkill.typing}) {
    activeSession = LessonSession(
      id: 'test',
      scope: LessonScope.hiragana,
      focus: LessonFocus.balanced,
      questions: [LessonQuestion(id: 'one', itemId: item.id, skill: skill)],
      startedAt: DateTime(2026, 10, 16),
    );
  }

  String? submitted;
  InkSubmission? ink;
  int retries = 0;

  @override
  List<LearningItem> get curriculum => [item];
  @override
  Map<String, SkillProgress> get progress => {};
  @override
  LessonSession? activeSession;
  @override
  List<LearningItem> get introItems => [];
  @override
  AnswerFeedback? feedback;
  @override
  bool get loading => false;
  @override
  bool get busy => false;
  @override
  String? get error => null;
  @override
  bool get kanjiUnlocked => false;
  @override
  HandwritingModelStatus get modelStatus => HandwritingModelStatus.ready;
  @override
  Future<void> startLesson(LessonScope scope, LessonFocus focus) async {}
  @override
  void completeIntroduction() {}
  @override
  Future<void> submitText(String answer) async {
    submitted = answer;
  }

  @override
  Future<void> submitDrawing(InkSubmission value) async {
    ink = value;
  }

  @override
  Future<void> revealAnswer() async {}
  @override
  void retryAnswer() {
    retries++;
    feedback = null;
    notifyListeners();
  }

  @override
  Future<void> advance() async {}
  @override
  Future<void> exitLesson() async {}
  @override
  Future<void> abandonLesson() async {}
  @override
  Future<void> downloadModel() async {}
  @override
  Future<String> exportBackup() async => '{}';
  @override
  Future<void> importBackup(String json) async {}
  @override
  void clearError() {}
}

Future<void> _pumpLesson(WidgetTester tester, _Controller controller) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: kanaTheme(Brightness.light),
      home: LessonScreen(controller: controller),
    ),
  );
}

void main() {
  testWidgets('bundled stroke guides retain all numbered SVG labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StrokeGuide(glyph: 'あ')),
      ),
    );
    await tester.tap(find.text('Show stroke guide'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Japanese IME composition must be committed before grading', (
    tester,
  ) async {
    final controller = _Controller();
    await _pumpLesson(tester, controller);
    await tester.tap(find.byType(TextField));
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'あ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    expect(
      find.text('Finish choosing characters on your keyboard first.'),
      findsOneWidget,
    );
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Check answer'),
    );
    expect(disabled.onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(controller.submitted, isNull);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'あ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Check answer'));
    await tester.tap(find.text('Check answer'));
    await tester.pump();
    expect(controller.submitted, 'あ');
  });

  testWidgets(
    'drawing captures strokes in stable writing cells and supports undo',
    (tester) async {
      final key = GlobalKey<DrawingPadState>();
      var hasInk = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: DrawingPad(
                  key: key,
                  cells: 1,
                  enabled: true,
                  onChanged: (value) => hasInk = value,
                ),
              ),
            ),
          ),
        ),
      );
      final canvas = find
          .descendant(
            of: find.byType(DrawingPad),
            matching: find.byType(GestureDetector),
          )
          .first;
      await tester.dragFrom(
        tester.getCenter(canvas) - const Offset(35, 30),
        const Offset(60, 50),
      );
      await tester.pump();
      expect(hasInk, isTrue);
      expect(key.currentState!.submission.strokes, hasLength(1));
      expect(key.currentState!.submission.width, 290);
      expect(key.currentState!.submission.height, 290);
      final points = key.currentState!.submission.strokes.single.points;
      expect(points.length, greaterThan(1));
      expect(
        points.last.milliseconds,
        greaterThanOrEqualTo(points.first.milliseconds),
      );
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(hasInk, isFalse);
      expect(key.currentState!.submission.strokes, isEmpty);
    },
  );

  testWidgets(
    'uncertain handwriting offers ungraded redraw on the same question',
    (tester) async {
      final controller = _Controller(skill: PracticeSkill.drawing);
      controller.feedback = const AnswerFeedback(
        outcome: ReviewOutcome.neutral,
        response: 'お',
        message: 'Please redraw; no progress changed.',
      );
      await _pumpLesson(tester, controller);
      expect(find.text('Please redraw; no progress changed.'), findsOneWidget);
      expect(find.text('Expected answer'), findsNothing);
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(controller.retries, 1);
      expect(controller.activeSession!.currentIndex, 0);
      expect(find.text('Check answer'), findsOneWidget);
    },
  );
}
