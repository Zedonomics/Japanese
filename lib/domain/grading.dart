import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'models.dart';

class Grader {
  const Grader._();

  /// NFKC accepts width variants and decomposed dakuten without changing script.
  static String normalizeJapanese(String value) => unorm.nfkc(value).trim();

  static String normalizeRomaji(String value) =>
      unorm.nfkc(value).trim().toLowerCase();

  static ReviewOutcome typed(
    LearningItem item,
    PracticeSkill skill,
    String answer,
  ) {
    if (skill == PracticeSkill.drawing) {
      throw ArgumentError('Use drawing() for ink recognition candidates.');
    }
    if (skill == PracticeSkill.reading && !item.isKanji) {
      final actual = normalizeRomaji(answer);
      final expected = [
        item.romaji,
        ...item.romajiAliases,
      ].where((entry) => entry.isNotEmpty).map(normalizeRomaji);
      return actual.isNotEmpty && expected.contains(actual)
          ? ReviewOutcome.correct
          : ReviewOutcome.incorrect;
    }
    final expected = skill == PracticeSkill.reading
        ? item.readingKana ?? ''
        : item.glyph;
    final actual = normalizeJapanese(answer);
    return actual.isNotEmpty && actual == normalizeJapanese(expected)
        ? ReviewOutcome.correct
        : ReviewOutcome.incorrect;
  }

  /// Compare complete native candidate strings, in their original ranking.
  /// A lower-ranked match is uncertain rather than a false pass or penalty.
  static ReviewOutcome drawing(LearningItem item, List<String> candidates) {
    if (candidates.isEmpty) {
      return ReviewOutcome.neutral;
    }
    final accepted = {
      item.glyph,
      ...item.drawingAliases,
    }.map(normalizeJapanese).where((entry) => entry.isNotEmpty).toSet();
    final topThree = candidates.take(3).map(normalizeJapanese).toList();
    if (topThree.first.isEmpty) {
      return ReviewOutcome.neutral;
    }
    if (accepted.contains(topThree.first)) {
      return ReviewOutcome.correct;
    }
    if (topThree.skip(1).any(accepted.contains)) {
      return ReviewOutcome.neutral;
    }
    return ReviewOutcome.incorrect;
  }
}
