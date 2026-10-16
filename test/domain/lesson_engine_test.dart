import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/domain/domain.dart';

void main() {
  final now = DateTime(2026, 10, 16, 12);
  final items = [
    for (var i = 0; i < 8; i++)
      LearningItem(
        id: 'h-$i',
        script: ScriptKind.hiragana,
        glyph: ['あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く'][i],
        romaji: ['a', 'i', 'u', 'e', 'o', 'ka', 'ki', 'ku'][i],
        order: i,
      ),
    const LearningItem(
      id: 'k-a',
      script: ScriptKind.katakana,
      glyph: 'ア',
      romaji: 'a',
      order: 10,
    ),
    const LearningItem(
      id: 'j-person',
      script: ScriptKind.kanji,
      glyph: '人',
      readingKana: 'ひと',
      meaning: 'person',
      order: 20,
    ),
  ];

  LessonSession build({
    List<LearningItem>? curriculum,
    Map<String, SkillProgress> progress = const {},
    LessonScope scope = LessonScope.hiragana,
    LessonFocus focus = LessonFocus.balanced,
    bool unlocked = false,
    bool drawingAvailable = true,
  }) => const LessonEngine().build(
    items: curriculum ?? items,
    progress: progress,
    scope: scope,
    focus: focus,
    kanjiUnlocked: unlocked,
    now: now,
    drawingAvailable: drawingAvailable,
  );

  test(
    'fresh balanced lesson has ten questions and at most three new targets',
    () {
      final session = build();
      expect(session.questions.length, 10);
      expect(session.questions.map((q) => q.itemId).toSet().length, 3);
      expect(
        session.questions.map((q) => q.skill).toSet(),
        PracticeSkill.values.toSet(),
      );
      expect(session.questions.map((q) => q.id).toSet().length, 10);
    },
  );

  test('focus changes skill while retaining the three-new-target limit', () {
    final session = build(focus: LessonFocus.drawing);
    expect(session.questions.length, 10);
    expect(
      session.questions.every((q) => q.skill == PracticeSkill.drawing),
      isTrue,
    );
    expect(session.questions.map((q) => q.itemId).toSet().length, 3);
  });

  test(
    'balanced practice skips drawing without a model, explicit drawing remains available',
    () {
      final balanced = build(drawingAvailable: false);
      expect(balanced.questions, hasLength(10));
      expect(
        balanced.questions.any((q) => q.skill == PracticeSkill.drawing),
        isFalse,
      );
      expect(balanced.questions.map((q) => q.skill).toSet(), {
        PracticeSkill.reading,
        PracticeSkill.typing,
      });
      for (final skill in [PracticeSkill.reading, PracticeSkill.typing]) {
        expect(balanced.questions.where((q) => q.skill == skill), hasLength(5));
      }
      final drawing = build(
        focus: LessonFocus.drawing,
        drawingAvailable: false,
      );
      expect(drawing.questions, hasLength(10));
      expect(
        drawing.questions.every((q) => q.skill == PracticeSkill.drawing),
        isTrue,
      );
    },
  );

  test('due recent errors come before new items and non-due practice', () {
    final recentError = SkillProgress(
      itemId: 'h-7',
      skill: PracticeSkill.reading,
      dueAt: now.subtract(const Duration(minutes: 1)),
      lastIncorrectAt: now.subtract(const Duration(minutes: 11)),
    );
    final dueReview = SkillProgress(
      itemId: 'h-6',
      skill: PracticeSkill.reading,
      successfulReviews: 2,
      dueAt: now.subtract(const Duration(days: 1)),
    );
    final early = SkillProgress(
      itemId: 'h-5',
      skill: PracticeSkill.reading,
      successfulReviews: 2,
      dueAt: now.add(const Duration(days: 1)),
    );
    final session = build(
      focus: LessonFocus.reading,
      progress: {
        for (final p in [recentError, dueReview, early]) p.key: p,
      },
    );
    expect(session.questions[0].itemId, 'h-7');
    expect(session.questions[1].itemId, 'h-6');
    final known = {'h-7', 'h-6', 'h-5'};
    expect(
      session.questions.map((q) => q.itemId).toSet().difference(known).length,
      lessThanOrEqualTo(3),
    );
  });

  test('mixed filters locked kanji and honors unlocking', () {
    final locked = build(scope: LessonScope.mixed);
    expect(locked.questions.any((q) => q.itemId == 'j-person'), isFalse);
    expect(build(scope: LessonScope.kanji).questions, isEmpty);
    final unlocked = build(scope: LessonScope.kanji, unlocked: true);
    expect(unlocked.questions.length, 10);
    expect(unlocked.questions.every((q) => q.itemId == 'j-person'), isTrue);
  });

  test('session JSON preserves answer history and exact recovery cursor', () {
    final session = build();
    final question = session.currentQuestion!;
    final answered = session.withAttempt(
      ReviewAttempt(
        questionId: question.id,
        itemId: question.itemId,
        skill: question.skill,
        outcome: ReviewOutcome.correct,
        answeredAt: now,
        response: 'a',
      ),
      advance: false,
    );
    final restored = LessonSession.fromJson(
      jsonDecode(jsonEncode(answered.toJson())) as Map<String, dynamic>,
    );
    expect(restored.currentIndex, 0);
    expect(restored.currentQuestion!.id, question.id);
    expect(restored.attempts.single.response, 'a');
    expect(restored.correctCount, 1);
    expect(restored.advance().currentIndex, 1);
    expect(restored.toJson(), answered.toJson());
  });

  test(
    'neutral attempts do not advance, and unrelated attempts are refused',
    () {
      final session = build();
      final question = session.currentQuestion!;
      final neutral = session.withAttempt(
        ReviewAttempt(
          questionId: question.id,
          itemId: question.itemId,
          skill: question.skill,
          outcome: ReviewOutcome.neutral,
          answeredAt: now,
        ),
      );
      expect(neutral.currentIndex, 0);
      expect(neutral.gradedCount, 0);
      expect(
        () => session.withAttempt(
          ReviewAttempt(
            questionId: 'other',
            itemId: question.itemId,
            skill: question.skill,
            outcome: ReviewOutcome.correct,
            answeredAt: now,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('curriculum JSON round trips contextual and ambiguity metadata', () {
    const item = LearningItem(
      id: 'd-ji',
      script: ScriptKind.hiragana,
      glyph: 'ぢ',
      romaji: 'ji',
      romajiAliases: ['di'],
      productionCue: 'Voiced chi from the t row.',
      gateRequired: true,
    );
    final restored = LearningItem.fromJson(item.toJson());
    expect(restored.toJson(), item.toJson());
    final progress = SkillProgress(
      itemId: 'd-ji',
      skill: PracticeSkill.typing,
      successfulReviews: 2,
      dueAt: now,
      lastAdvancedDate: '2026-10-15',
    );
    expect(
      SkillProgress.fromJson(progress.toJson()).toJson(),
      progress.toJson(),
    );
  });
}
