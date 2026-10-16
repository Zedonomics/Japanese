import 'models.dart';

class ReviewScheduler {
  const ReviewScheduler._();

  /// After successes 1/2/3/4/5+, wait 1/3/7/14/30 days respectively.
  static const intervals = [1, 3, 7, 14, 30];

  /// The caller supplies local time so a calendar date follows the learner.
  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static SkillProgress apply(SkillProgress? previous, ReviewAttempt attempt) {
    final prior =
        previous ?? SkillProgress(itemId: attempt.itemId, skill: attempt.skill);
    if (prior.itemId != attempt.itemId || prior.skill != attempt.skill) {
      throw ArgumentError('Progress and attempt must describe the same skill.');
    }
    if (attempt.outcome == ReviewOutcome.neutral) {
      return prior;
    }

    final correct =
        attempt.outcome == ReviewOutcome.correct && !attempt.assisted;
    final today = dateKey(attempt.answeredAt);
    final canAdvance =
        correct &&
        prior.isDue(attempt.answeredAt) &&
        prior.lastAdvancedDate != today;
    final successes = correct
        ? prior.successfulReviews + (canAdvance ? 1 : 0)
        : 0;
    DateTime? dueAt = prior.dueAt;
    if (!correct) {
      dueAt = attempt.answeredAt.add(const Duration(minutes: 10));
    } else if (canAdvance) {
      final intervalIndex = (successes - 1)
          .clamp(0, intervals.length - 1)
          .toInt();
      dueAt = attempt.answeredAt.add(Duration(days: intervals[intervalIndex]));
    }
    return SkillProgress(
      itemId: prior.itemId,
      skill: prior.skill,
      successfulReviews: successes,
      dueAt: dueAt,
      lastAdvancedDate: canAdvance ? today : prior.lastAdvancedDate,
      lastAttemptAt: attempt.answeredAt,
      lastIncorrectAt: correct ? prior.lastIncorrectAt : attempt.answeredAt,
      correctCount: prior.correctCount + (correct ? 1 : 0),
      incorrectCount: prior.incorrectCount + (correct ? 0 : 1),
    );
  }
}

class KanjiUnlock {
  const KanjiUnlock._();

  static bool isEligible(
    List<LearningItem> items,
    Map<String, SkillProgress> progress,
  ) {
    final requiredItems = items
        .where((item) => !item.isKanji && item.gateRequired)
        .toList();
    // Missing either kana script must not accidentally bypass the gate.
    if (!requiredItems.any((i) => i.script == ScriptKind.hiragana) ||
        !requiredItems.any((i) => i.script == ScriptKind.katakana)) {
      return false;
    }
    return requiredItems.every(
      (item) => [PracticeSkill.reading, PracticeSkill.typing].every(
        (skill) =>
            progress[SkillProgress.keyFor(item.id, skill)]?.mastered ?? false,
      ),
    );
  }

  static bool update(
    bool previouslyUnlocked,
    List<LearningItem> items,
    Map<String, SkillProgress> progress,
  ) => previouslyUnlocked || isEligible(items, progress);
}
