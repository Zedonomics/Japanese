import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/app_controller.dart';
import 'package:kana_path/data/progress_repository.dart';
import 'package:kana_path/domain/domain.dart';
import 'package:kana_path/services/handwriting_service.dart';
import 'package:kana_path/ui/ui_contract.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeHandwriting implements HandwritingService {
  bool ready = true;
  Completer<bool>? readinessGate;
  bool failDownload = false;
  Completer<void>? downloadGate;
  int downloads = 0;
  Object? recognitionError;
  List<String> candidates = const ['あ'];
  List<List<InkSample>>? lastStrokes;
  double? lastWidth;
  double? lastHeight;

  @override
  Future<bool> isReady() => readinessGate?.future ?? Future.value(ready);

  @override
  Future<void> download() async {
    downloads++;
    if (failDownload) throw StateError('No network');
    await downloadGate?.future;
    ready = true;
  }

  @override
  Future<List<String>> recognize({
    required List<List<InkSample>> strokes,
    required double width,
    required double height,
  }) async {
    lastStrokes = strokes;
    lastWidth = width;
    lastHeight = height;
    if (recognitionError != null) throw recognitionError!;
    return candidates;
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime(2026, 10, 16, 9);
  const items = [
    LearningItem(
      id: 'h-a',
      script: ScriptKind.hiragana,
      glyph: 'あ',
      romaji: 'a',
    ),
    LearningItem(
      id: 'k-a',
      script: ScriptKind.katakana,
      glyph: 'ア',
      romaji: 'a',
    ),
    LearningItem(
      id: 'j-person',
      script: ScriptKind.kanji,
      glyph: '人',
      readingKana: 'ひと',
    ),
  ];
  late ProgressRepository repository;
  late FakeHandwriting handwriting;
  late AppController controller;

  setUp(() async {
    repository = await ProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    handwriting = FakeHandwriting();
    controller = AppController(
      repository: repository,
      handwriting: handwriting,
      curriculumLoader: () async => items,
      now: () => now,
    );
    await controller.initialize();
  });

  tearDown(() async => controller.close());

  Future<void> begin(LessonFocus focus) async {
    await controller.startLesson(LessonScope.hiragana, focus);
    controller.completeIntroduction();
    while (controller.busy) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.introItems, isEmpty);
  }

  const ink = InkSubmission(
    strokes: [
      InkStroke([InkPoint(20, 30, 1), InkPoint(70, 90, 2)]),
    ],
    width: 240,
    height: 240,
  );

  test(
    'an unresponsive handwriting readiness check cannot block startup lessons',
    () async {
      handwriting.readinessGate = Completer<bool>();
      controller = AppController(
        repository: repository,
        handwriting: handwriting,
        curriculumLoader: () async => items,
        now: () => now,
      );
      expect(controller.loading, isTrue);
      await controller.initialize().timeout(const Duration(seconds: 7));

      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.modelStatus, HandwritingModelStatus.failed);
      await begin(LessonFocus.reading);
      await controller.submitText('a');
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
      expect(controller.progress['h-a:reading']!.correctCount, 1);

      // A failed readiness probe still permits the model's normal retry path.
      await controller.downloadModel();
      expect(controller.modelStatus, HandwritingModelStatus.ready);
      expect(handwriting.downloads, 1);
    },
  );

  test(
    'keyboard answer saves feedback before Next and ignores duplicate submission',
    () async {
      await begin(LessonFocus.reading);
      await controller.submitText('a');
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
      expect(controller.activeSession!.currentIndex, 0);
      expect(controller.progress['h-a:reading']!.successfulReviews, 1);
      await controller.submitText('a');
      expect(controller.progress['h-a:reading']!.correctCount, 1);
      final checkpoint = (await repository.load()).checkpoint!;
      expect(checkpoint.feedback!['outcome'], 'correct');
      expect(checkpoint.session.attempts, hasLength(1));
      await controller.advance();
      expect(controller.activeSession!.currentIndex, 1);
      expect(controller.feedback, isNull);
      expect((await repository.load()).checkpoint!.feedback, isNull);
    },
  );

  test(
    'uncertain drawing is ungraded and preserves the native writing area',
    () async {
      await begin(LessonFocus.drawing);
      handwriting.candidates = ['お', 'あ'];
      await controller.submitDrawing(ink);
      expect(controller.feedback!.outcome, ReviewOutcome.neutral);
      expect(controller.progress, isEmpty);
      expect(controller.activeSession!.attempts, isEmpty);
      expect(controller.activeSession!.currentIndex, 0);
      expect(handwriting.lastWidth, 240);
      expect(handwriting.lastHeight, 240);
      expect(handwriting.lastStrokes!.single.last.x, 70);
      await controller.advance();
      expect(controller.activeSession!.currentIndex, 0);
      handwriting.candidates = ['あ'];
      controller.retryAnswer();
      await controller.submitDrawing(ink);
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
      expect(controller.progress['h-a:drawing']!.successfulReviews, 1);
    },
  );

  test(
    'recognition timeout leaves the question and progress untouched',
    () async {
      await begin(LessonFocus.drawing);
      handwriting.recognitionError = TimeoutException('recognizer');
      await controller.submitDrawing(ink);
      expect(controller.error, contains('timed out'));
      expect(controller.feedback, isNull);
      expect(controller.progress, isEmpty);
      expect(controller.activeSession!.currentIndex, 0);
      final backup =
          jsonDecode(await controller.exportBackup()) as Map<String, dynamic>;
      expect(backup['attempts'], isEmpty);
    },
  );

  test(
    'revealed answer schedules a review instead of granting success',
    () async {
      await begin(LessonFocus.typing);
      await controller.revealAnswer();
      final progress = controller.progress['h-a:typing']!;
      expect(controller.feedback!.outcome, ReviewOutcome.revealed);
      expect(progress.successfulReviews, 0);
      expect(progress.dueAt, now.add(const Duration(minutes: 10)));
      expect(progress.incorrectCount, 1);
    },
  );

  test(
    'locked kanji cannot start and failed model download does not block typing',
    () async {
      await controller.startLesson(LessonScope.kanji, LessonFocus.reading);
      expect(controller.error, contains('unlock kanji'));
      expect(controller.activeSession, isNull);
      handwriting.ready = false;
      await controller.initialize();
      handwriting.failDownload = true;
      await controller.downloadModel();
      expect(controller.modelStatus, HandwritingModelStatus.failed);
      await begin(LessonFocus.typing);
      await controller.submitText('あ');
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
    },
  );

  test(
    'model download runs independently of lessons and cannot start twice',
    () async {
      handwriting.ready = false;
      handwriting.downloadGate = Completer<void>();
      await controller.initialize();
      final downloading = controller.downloadModel();
      expect(controller.modelStatus, HandwritingModelStatus.downloading);
      expect(controller.busy, isFalse);
      await controller.downloadModel();
      expect(handwriting.downloads, 1);
      await begin(LessonFocus.balanced);
      expect(
        controller.activeSession!.questions.every(
          (q) => q.skill != PracticeSkill.drawing,
        ),
        isTrue,
      );
      await controller.submitText('a');
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
      handwriting.downloadGate!.complete();
      await downloading;
      expect(controller.modelStatus, HandwritingModelStatus.ready);
    },
  );

  test(
    'invalid backup preserves active lesson; valid backup restores feedback',
    () async {
      await begin(LessonFocus.reading);
      await controller.submitText('a');
      final backup = await controller.exportBackup();
      await expectLater(
        controller.importBackup('broken'),
        throwsFormatException,
      );
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
      expect(controller.activeSession!.currentIndex, 0);
      await controller.advance();
      await controller.importBackup(backup);
      expect(controller.activeSession!.currentIndex, 0);
      expect(controller.feedback!.outcome, ReviewOutcome.correct);
      expect(controller.progress['h-a:reading']!.correctCount, 1);
      await controller.submitText('a');
      expect(controller.progress['h-a:reading']!.correctCount, 1);
    },
  );
}
