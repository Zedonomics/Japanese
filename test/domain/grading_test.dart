import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/domain/domain.dart';

void main() {
  const shi = LearningItem(
    id: 'h-shi',
    script: ScriptKind.hiragana,
    glyph: 'し',
    romaji: 'shi',
    romajiAliases: ['si'],
  );
  const ga = LearningItem(
    id: 'h-ga',
    script: ScriptKind.hiragana,
    glyph: 'が',
    romaji: 'ga',
  );
  const ka = LearningItem(
    id: 'k-ka',
    script: ScriptKind.katakana,
    glyph: 'カ',
    romaji: 'ka',
    drawingAliases: ['力'],
  );
  const person = LearningItem(
    id: 'kanji-person',
    script: ScriptKind.kanji,
    glyph: '人',
    readingKana: 'ひと',
    meaning: 'person',
  );

  test('romaji accepts declared aliases, width and case, not guesses', () {
    expect(
      Grader.typed(shi, PracticeSkill.reading, ' ＳＩ '),
      ReviewOutcome.correct,
    );
    expect(
      Grader.typed(shi, PracticeSkill.reading, 'shi!'),
      ReviewOutcome.incorrect,
    );
    expect(
      Grader.typed(shi, PracticeSkill.reading, ''),
      ReviewOutcome.incorrect,
    );
  });

  test('Japanese normalization composes dakuten and preserves script', () {
    expect(
      Grader.typed(ga, PracticeSkill.typing, 'か\u3099'),
      ReviewOutcome.correct,
    );
    expect(
      Grader.typed(ga, PracticeSkill.typing, 'ガ'),
      ReviewOutcome.incorrect,
    );
    expect(Grader.typed(ka, PracticeSkill.typing, 'ｶ'), ReviewOutcome.correct);
    expect(
      Grader.typed(ka, PracticeSkill.typing, '力'),
      ReviewOutcome.incorrect,
    );
    expect(
      Grader.typed(ka, PracticeSkill.typing, 'か'),
      ReviewOutcome.incorrect,
    );
  });

  test('kanji reading requires kana; production requires the kanji', () {
    expect(
      Grader.typed(person, PracticeSkill.reading, 'ひと'),
      ReviewOutcome.correct,
    );
    expect(
      Grader.typed(person, PracticeSkill.reading, 'hito'),
      ReviewOutcome.incorrect,
    );
    expect(
      Grader.typed(person, PracticeSkill.typing, '人'),
      ReviewOutcome.correct,
    );
    expect(
      Grader.typed(person, PracticeSkill.typing, 'ひと'),
      ReviewOutcome.incorrect,
    );
  });

  test('drawing exact top one passes; ranks two and three are neutral', () {
    expect(Grader.drawing(shi, ['し', 'つ']), ReviewOutcome.correct);
    expect(Grader.drawing(shi, ['つ', 'し']), ReviewOutcome.neutral);
    expect(Grader.drawing(shi, ['つ', 'う', 'し']), ReviewOutcome.neutral);
    expect(Grader.drawing(shi, ['つ', 'う', 'く', 'し']), ReviewOutcome.incorrect);
    expect(Grader.drawing(shi, ['しつ']), ReviewOutcome.incorrect);
    expect(Grader.drawing(shi, []), ReviewOutcome.neutral);
    expect(Grader.drawing(shi, ['']), ReviewOutcome.neutral);
  });

  test('only drawing accepts explicitly declared identical glyph aliases', () {
    expect(Grader.drawing(ka, ['力']), ReviewOutcome.correct);
    expect(Grader.drawing(ka, ['か']), ReviewOutcome.incorrect);
    expect(
      Grader.typed(ka, PracticeSkill.typing, '力'),
      ReviewOutcome.incorrect,
    );
  });

  test(
    'contextual symbols use example reading without giving a fake sound',
    () {
      const symbol = LearningItem(
        id: 'h-small-tsu',
        script: ScriptKind.hiragana,
        glyph: 'っ',
        romaji: 'kitte',
        contextWord: 'きって',
        contextual: true,
        productionCue: 'Enter only the small pause marker.',
        gateRequired: false,
      );
      const question = LessonQuestion(
        id: 'q',
        itemId: 'h-small-tsu',
        skill: PracticeSkill.reading,
      );
      expect(question.displayFor(symbol), 'きって');
      expect(question.expectedAnswerFor(symbol), 'kitte');
      expect(
        Grader.typed(symbol, PracticeSkill.reading, 'kitte'),
        ReviewOutcome.correct,
      );
      expect(
        Grader.typed(symbol, PracticeSkill.typing, 'つ'),
        ReviewOutcome.incorrect,
      );
    },
  );
}
