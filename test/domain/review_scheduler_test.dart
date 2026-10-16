import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/domain/domain.dart';

void main() {
  final dayZero = DateTime(2026, 10, 16, 9);

  ReviewAttempt attempt(
    DateTime at, {
    ReviewOutcome outcome = ReviewOutcome.correct,
    bool assisted = false,
    PracticeSkill skill = PracticeSkill.reading,
  }) => ReviewAttempt(
    questionId: 'q',
    itemId: 'a',
    skill: skill,
    outcome: outcome,
    answeredAt: at,
    assisted: assisted,
  );

  test(
    'three spaced successes master a skill; later reviews extend intervals',
    () {
      var state = ReviewScheduler.apply(null, attempt(dayZero));
      expect(state.successfulReviews, 1);
      expect(state.dueAt, dayZero.add(const Duration(days: 1)));
      expect(state.mastered, isFalse);
      state = ReviewScheduler.apply(state, attempt(state.dueAt!));
      expect(state.successfulReviews, 2);
      expect(state.dueAt, dayZero.add(const Duration(days: 4)));
      state = ReviewScheduler.apply(state, attempt(state.dueAt!));
      expect(state.mastered, isTrue);
      expect(state.dueAt, dayZero.add(const Duration(days: 11)));
      state = ReviewScheduler.apply(state, attempt(state.dueAt!));
      expect(state.dueAt, dayZero.add(const Duration(days: 25)));
      state = ReviewScheduler.apply(state, attempt(state.dueAt!));
      expect(state.dueAt, dayZero.add(const Duration(days: 55)));
    },
  );

  test(
    'early practice and repeated answers cannot advance the review schedule',
    () {
      final state = ReviewScheduler.apply(null, attempt(dayZero));
      final repeated = ReviewScheduler.apply(
        state,
        attempt(dayZero.add(const Duration(minutes: 1))),
      );
      expect(repeated.successfulReviews, 1);
      expect(repeated.dueAt, state.dueAt);
      expect(repeated.correctCount, 2);
      final nextDateButNotDue = ReviewScheduler.apply(
        state,
        attempt(DateTime(2026, 10, 17, 8)),
      );
      expect(nextDateButNotDue.successfulReviews, 1);
    },
  );

  test(
    'mistakes and reveals reset mastery and schedule a ten minute review',
    () {
      const outcomes = [ReviewOutcome.incorrect, ReviewOutcome.revealed];
      for (final outcome in outcomes) {
        final mastered = SkillProgress(
          itemId: 'a',
          skill: PracticeSkill.reading,
          successfulReviews: 3,
          dueAt: dayZero,
        );
        final reset = ReviewScheduler.apply(
          mastered,
          attempt(dayZero, outcome: outcome),
        );
        expect(reset.successfulReviews, 0);
        expect(reset.mastered, isFalse);
        expect(reset.dueAt, dayZero.add(const Duration(minutes: 10)));
        expect(reset.incorrectCount, 1);
        final immediateRetry = ReviewScheduler.apply(
          reset,
          attempt(dayZero.add(const Duration(minutes: 1))),
        );
        expect(immediateRetry.successfulReviews, 0);
        expect(immediateRetry.dueAt, reset.dueAt);
      }
    },
  );

  test('an assisted correct answer resets progress like a reveal', () {
    final before = ReviewScheduler.apply(null, attempt(dayZero));
    final reset = ReviewScheduler.apply(
      before,
      attempt(dayZero.add(const Duration(days: 1)), assisted: true),
    );
    expect(reset.successfulReviews, 0);
    expect(reset.incorrectCount, 1);
  });

  test('reset preserves one-advancement-per-date protection', () {
    final first = ReviewScheduler.apply(null, attempt(dayZero));
    final error = ReviewScheduler.apply(
      first,
      attempt(
        dayZero.add(const Duration(minutes: 1)),
        outcome: ReviewOutcome.incorrect,
      ),
    );
    final retry = ReviewScheduler.apply(
      error,
      attempt(dayZero.add(const Duration(minutes: 15))),
    );
    expect(retry.successfulReviews, 0);
    expect(retry.lastAdvancedDate, '2026-10-16');
    final tomorrow = ReviewScheduler.apply(
      retry,
      attempt(dayZero.add(const Duration(days: 1))),
    );
    expect(tomorrow.successfulReviews, 1);
  });

  test('neutral recognition leaves existing progress exactly unchanged', () {
    final state = ReviewScheduler.apply(null, attempt(dayZero));
    expect(
      identical(
        state,
        ReviewScheduler.apply(
          state,
          attempt(dayZero, outcome: ReviewOutcome.neutral),
        ),
      ),
      isTrue,
    );
  });

  test(
    'kanji gate requires both kana scripts, reading and typing; unlock latches',
    () {
      const items = [
        LearningItem(
          id: 'a',
          script: ScriptKind.hiragana,
          glyph: 'あ',
          romaji: 'a',
        ),
        LearningItem(
          id: 'ka',
          script: ScriptKind.katakana,
          glyph: 'カ',
          romaji: 'ka',
        ),
        LearningItem(
          id: 'symbol',
          script: ScriptKind.hiragana,
          glyph: 'っ',
          gateRequired: false,
        ),
      ];
      final progress = <String, SkillProgress>{};
      for (final item in items.take(2)) {
        for (final skill in [PracticeSkill.reading, PracticeSkill.typing]) {
          final state = SkillProgress(
            itemId: item.id,
            skill: skill,
            successfulReviews: 3,
          );
          progress[state.key] = state;
        }
      }
      expect(KanjiUnlock.isEligible(items, progress), isTrue);
      progress.remove('ka:typing');
      expect(KanjiUnlock.isEligible(items, progress), isFalse);
      expect(KanjiUnlock.update(true, items, progress), isTrue);
      expect(KanjiUnlock.isEligible([], {}), isFalse);
      expect(KanjiUnlock.isEligible(items.take(1).toList(), progress), isFalse);
    },
  );
}
