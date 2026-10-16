import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/data/progress_repository.dart';
import 'package:kana_path/domain/domain.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String databasePath;
  late ProgressRepository repository;
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
  ];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kana_path_repository_');
    databasePath = '${directory.path}${Platform.pathSeparator}progress.db';
    repository = await ProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
  });

  tearDown(() async {
    await repository.close();
    // Only files created in this test's private temporary directory are removed.
    final actual = directory.absolute.path;
    final tempPrefix =
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}kana_path_repository_';
    if (!actual.startsWith(tempPrefix)) {
      throw StateError('Unexpected test path');
    }
    await directory.delete(recursive: true);
  });

  LessonSession lesson() => const LessonEngine().build(
    items: items,
    progress: {},
    scope: LessonScope.hiragana,
    focus: LessonFocus.reading,
    kanjiUnlocked: false,
    now: now,
  );

  ReviewAttempt answerFor(LessonSession session) => ReviewAttempt(
    questionId: session.currentQuestion!.id,
    itemId: session.currentQuestion!.itemId,
    skill: session.currentQuestion!.skill,
    outcome: ReviewOutcome.correct,
    answeredAt: now,
    response: 'a',
  );

  Future<void> saveFirstAnswer({bool unlocked = false}) async {
    final session = lesson();
    final answer = answerFor(session);
    final state = ReviewScheduler.apply(null, answer);
    await repository.saveAnswer(
      attempt: answer,
      progress: state,
      kanjiUnlocked: unlocked,
      checkpoint: LessonCheckpoint(
        session: session.withAttempt(answer, advance: false),
        feedback: {'outcome': 'correct', 'response': 'a', 'message': null},
      ),
    );
  }

  test(
    'answers, feedback and cursor survive a database close and reopen',
    () async {
      await saveFirstAnswer(unlocked: true);
      await repository.close();
      repository = await ProgressRepository.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final restored = await repository.load();
      expect(restored.progress['h-a:reading']!.successfulReviews, 1);
      expect(restored.kanjiUnlocked, isTrue);
      expect(restored.checkpoint!.session.currentIndex, 0);
      expect(restored.checkpoint!.session.attempts.single.response, 'a');
      expect(restored.checkpoint!.feedback!['outcome'], 'correct');
      final backup =
          jsonDecode(await repository.exportBackup()) as Map<String, dynamic>;
      expect(backup['attempts'], hasLength(1));
    },
  );

  test(
    'repeated question save cannot overwrite progress, unlock or checkpoint',
    () async {
      await saveFirstAnswer(unlocked: true);
      final original = await repository.exportBackup(now: now);
      final session = lesson();
      final answer = answerFor(session);
      final result = await repository.saveAnswer(
        attempt: answer,
        progress: const SkillProgress(
          itemId: 'h-a',
          skill: PracticeSkill.reading,
        ),
        kanjiUnlocked: false,
        checkpoint: LessonCheckpoint(session: session.advance()),
      );
      expect(result, isFalse);
      expect(await repository.exportBackup(now: now), original);
    },
  );

  test(
    'an answer transaction rolls back if checkpoint serialization fails',
    () async {
      final before = await repository.exportBackup(now: now);
      final session = lesson();
      final answer = answerFor(session);
      await expectLater(
        repository.saveAnswer(
          attempt: answer,
          progress: ReviewScheduler.apply(null, answer),
          kanjiUnlocked: true,
          checkpoint: LessonCheckpoint(
            session: session,
            feedback: {'cannotEncode': Object()},
          ),
        ),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(await repository.exportBackup(now: now), before);
    },
  );

  test('invalid imports leave the previous database fully intact', () async {
    await saveFirstAnswer();
    final original = await repository.exportBackup(now: now);
    final invalid = jsonDecode(original) as Map<String, dynamic>;
    (invalid['progress'] as List).add((invalid['progress'] as List).first);
    await expectLater(
      repository.restoreBackup(jsonEncode(invalid), {'h-a', 'k-a'}),
      throwsFormatException,
    );
    expect(await repository.exportBackup(now: now), original);
    await expectLater(
      repository.restoreBackup('not json', {'h-a', 'k-a'}),
      throwsFormatException,
    );
    expect(await repository.exportBackup(now: now), original);
  });

  test(
    'valid backup restores exact feedback and history after local changes',
    () async {
      await saveFirstAnswer(unlocked: true);
      final backup = await repository.exportBackup(now: now);
      await repository.saveCheckpoint(null);
      await repository.saveUnlock(false);
      await repository.restoreBackup(backup, {'h-a', 'k-a'});
      expect(await repository.exportBackup(now: now), backup);
      final state = await repository.load();
      expect(state.checkpoint!.feedback!['response'], 'a');
      expect(state.checkpoint!.session.currentIndex, 0);
      expect(state.kanjiUnlocked, isTrue);
    },
  );

  test(
    'backup validation refuses unknown targets and invalid recovery cursors',
    () async {
      await saveFirstAnswer();
      final backup = await repository.exportBackup(now: now);
      expect(
        () => BackupCodec.validate(backup, {'k-a'}),
        throwsFormatException,
      );
      final invalid = jsonDecode(backup) as Map<String, dynamic>;
      ((invalid['checkpoint'] as Map)['session'] as Map)['currentIndex'] = -1;
      expect(
        () => BackupCodec.validate(jsonEncode(invalid), {'h-a', 'k-a'}),
        throwsFormatException,
      );
    },
  );

  test(
    'backup rejects contradictory session history, feedback, and cursor ordering',
    () async {
      await saveFirstAnswer();
      final original = await repository.exportBackup(now: now);

      final changedHistory = jsonDecode(original) as Map<String, dynamic>;
      final historySession =
          ((changedHistory['checkpoint'] as Map)['session'] as Map);
      ((historySession['attempts'] as List).first as Map)['response'] =
          'different';
      expect(
        () => BackupCodec.validate(jsonEncode(changedHistory), {'h-a', 'k-a'}),
        throwsFormatException,
      );

      final changedFeedback = jsonDecode(original) as Map<String, dynamic>;
      ((changedFeedback['checkpoint'] as Map)['feedback'] as Map)['outcome'] =
          'incorrect';
      expect(
        () => BackupCodec.validate(jsonEncode(changedFeedback), {'h-a', 'k-a'}),
        throwsFormatException,
      );

      final skippedCursor = jsonDecode(original) as Map<String, dynamic>;
      ((skippedCursor['checkpoint'] as Map)['session'] as Map)['currentIndex'] =
          3;
      expect(
        () => BackupCodec.validate(jsonEncode(skippedCursor), {'h-a', 'k-a'}),
        throwsFormatException,
      );

      final swappedOrder = jsonDecode(original) as Map<String, dynamic>;
      final questions =
          (((swappedOrder['checkpoint'] as Map)['session'] as Map)['questions']
              as List);
      final first = questions[0];
      questions[0] = questions[1];
      questions[1] = first;
      expect(
        () => BackupCodec.validate(jsonEncode(swappedOrder), {'h-a', 'k-a'}),
        throwsFormatException,
      );
      expect(await repository.exportBackup(now: now), original);
    },
  );
}
