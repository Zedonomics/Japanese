import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/domain/domain.dart';

void main() {
  late List<Map<String, dynamic>> rawItems;
  late List<LearningItem> items;

  setUpAll(() {
    final root =
        jsonDecode(File('assets/curriculum/items.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(root['version'], 1);
    rawItems = (root['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    items = rawItems.map(LearningItem.fromJson).toList();
  });

  test('bundles exactly the promised kana groups and 100 ranked kanji', () {
    expect(items, hasLength(311));
    expect(items.map((item) => item.id).toSet(), hasLength(items.length));
    for (final script in ['hiragana', 'katakana']) {
      for (final group in {
        'basic': 46,
        'voiced': 25,
        'contracted': 33,
      }.entries) {
        final matches = rawItems.where(
          (item) => item['script'] == script && item['group'] == group.key,
        );
        expect(matches, hasLength(group.value), reason: '$script ${group.key}');
        expect(matches.every((item) => item['gateRequired'] == true), isTrue);
      }
    }
    expect(items.where((item) => item.gateRequired), hasLength(208));
    final kanji = items.where((item) => item.isKanji).toList();
    expect(kanji, hasLength(100));
    expect(
      kanji.map((item) => item.frequencyRank),
      orderedEquals(List.generate(100, (i) => i + 1)),
    );
    expect(kanji.map((item) => item.glyph).take(5), ['日', '一', '国', '会', '人']);
    expect(kanji.last.glyph, '法');
    expect(kanji.every((item) => !item.gateRequired), isTrue);
  });

  test(
    'symbols are tested in context rather than assigned standalone sounds',
    () {
      final contextual = items.where((item) => item.contextual).toList();
      expect(contextual.map((item) => item.glyph).toSet(), {'っ', 'ッ', 'ー'});
      final expectedExamples = {
        'っ': ('きって', 'kitte'),
        'ッ': ('カップ', 'kappu'),
        'ー': ('コーヒー', 'koohii'),
      };
      for (final item in contextual) {
        expect(item.gateRequired, isFalse);
        final example = expectedExamples[item.glyph]!;
        expect(item.contextWord, example.$1);
        expect(item.romaji, example.$2);
        final reading = LessonQuestion(
          id: 'reading',
          itemId: item.id,
          skill: PracticeSkill.reading,
        );
        final typing = LessonQuestion(
          id: 'typing',
          itemId: item.id,
          skill: PracticeSkill.typing,
        );
        expect(reading.displayFor(item), example.$1);
        expect(reading.expectedAnswerFor(item), example.$2);
        expect(typing.displayFor(item), example.$2);
        expect(typing.expectedAnswerFor(item), item.glyph);
        expect(item.productionCue, contains('only'));
        expect(item.productionCue, contains('not the whole word'));
        expect(
          Grader.typed(item, PracticeSkill.reading, example.$2),
          ReviewOutcome.correct,
        );
        expect(
          Grader.typed(item, PracticeSkill.typing, example.$1),
          ReviewOutcome.incorrect,
        );
      }
    },
  );

  test(
    'every same-script romaji ambiguity has a distinct cue without leaking the answer',
    () {
      for (final script in [ScriptKind.hiragana, ScriptKind.katakana]) {
        final sounds = <String, Set<LearningItem>>{};
        for (final item in items.where(
          (item) => item.script == script && !item.contextual,
        )) {
          for (final sound in [item.romaji, ...item.romajiAliases]) {
            sounds
                .putIfAbsent(Grader.normalizeRomaji(sound), () => {})
                .add(item);
          }
        }
        final ambiguous = sounds.values.where((group) => group.length > 1);
        expect(ambiguous, isNotEmpty);
        for (final group in ambiguous) {
          expect(
            group.map((item) => item.productionCue).toSet(),
            hasLength(group.length),
          );
          for (final item in group) {
            expect(item.productionCue, isNotNull, reason: item.id);
            expect(item.productionCue!.trim(), isNotEmpty, reason: item.id);
          }
        }
      }
      for (final item in items.where((item) => !item.isKanji)) {
        if (item.productionCue != null) {
          expect(
            item.productionCue,
            isNot(contains(item.glyph)),
            reason: item.id,
          );
          expect(
            RegExp(
              r'[\u3040-\u30ff\u4e00-\u9fff]',
            ).hasMatch(item.productionCue!),
            isFalse,
            reason: item.id,
          );
        }
      }
    },
  );

  test(
    'all declared romaji variants pass while small kana remain distinct',
    () {
      for (final item in items.where((item) => !item.isKanji)) {
        for (final answer in [item.romaji, ...item.romajiAliases]) {
          expect(
            Grader.typed(item, PracticeSkill.reading, answer),
            ReviewOutcome.correct,
            reason: '${item.id}: $answer',
          );
        }
      }
      for (final glyph in ['し', 'ち', 'つ', 'ふ']) {
        final item = items.firstWhere((item) => item.glyph == glyph);
        expect(item.romajiAliases, isNotEmpty);
      }
      final smallTsu = items.firstWhere((item) => item.glyph == 'っ');
      expect(
        Grader.typed(smallTsu, PracticeSkill.typing, 'つ'),
        ReviewOutcome.incorrect,
      );
      final kya = items.firstWhere((item) => item.glyph == 'きゃ');
      expect(
        Grader.typed(kya, PracticeSkill.typing, 'きや'),
        ReviewOutcome.incorrect,
      );
    },
  );

  test(
    'kanji contexts specify one hiragana reading of the highlighted part',
    () {
      final evidence =
          (jsonDecode(
                    File(
                      'assets/curriculum/dictionary_evidence.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .map((entry) => Map<String, dynamic>.from(entry as Map));
      expect(evidence, hasLength(100));
      final evidenceByGlyph = {
        for (final entry in evidence) entry['glyph'] as String: entry,
      };
      for (final raw in rawItems.where((item) => item['script'] == 'kanji')) {
        final item = LearningItem.fromJson(raw);
        final reading = item.readingKana!;
        expect(
          RegExp(r'^[\u3041-\u3096]+$').hasMatch(reading),
          isTrue,
          reason: item.id,
        );
        expect(item.contextWord, isNotEmpty);
        expect(item.contextReading, contains(reading));
        expect(item.contextMeaning, isNotEmpty);
        expect(item.meaning, isNotEmpty);
        final start = raw['contextHighlightStart'] as int;
        expect(raw['contextHighlightLength'], 1);
        expect(item.contextWord!.substring(start, start + 1), item.glyph);
        expect(item.contextWord!.split(item.glyph), hasLength(2));
        final proof = evidenceByGlyph[item.glyph]!;
        expect(proof['contextWord'], item.contextWord);
        expect(proof['contextReading'], item.contextReading);
        expect(proof['readingKana'], reading);
        expect(proof['frequencyRank'], item.frequencyRank);
        expect(int.tryParse(proof['jmdictEntryId'] as String), greaterThan(0));
        expect(
          Grader.typed(item, PracticeSkill.reading, reading),
          ReviewOutcome.correct,
        );
        expect(
          Grader.typed(item, PracticeSkill.reading, item.glyph),
          ReviewOutcome.incorrect,
        );
      }
      for (final example in {
        '一': ('ひと', '一つ', 'ひとつ'),
        '長': ('なが', '長い', 'ながい'),
        '出': ('で', '出る', 'でる'),
        '分': ('わ', '分かる', 'わかる'),
        '同': ('おな', '同じ', 'おなじ'),
        '学': ('がく', '学生', 'がくせい'),
        '発': ('はつ', '発音', 'はつおん'),
        '回': ('かい', '一回', 'いっかい'),
        '通': ('とお', '通る', 'とおる'),
      }.entries) {
        final item = items.firstWhere((item) => item.glyph == example.key);
        expect(item.readingKana, example.value.$1);
        expect(item.contextWord, example.value.$2);
        expect(item.contextReading, example.value.$3);
      }
    },
  );

  test(
    'required kana exclude foreign-sound extensions and preserve script',
    () {
      const firstContracted = 'きしちにひみりぎじびぴ';
      for (final raw in rawItems.where(
        (item) => item['script'] != 'kanji' && item['contextual'] == false,
      )) {
        final glyph = raw['glyph'] as String;
        final hiragana = String.fromCharCodes(
          glyph.runes.map(
            (rune) => raw['script'] == 'katakana' ? rune - 0x60 : rune,
          ),
        );
        expect(
          hiragana.runes.every((rune) => rune >= 0x3041 && rune <= 0x3093),
          isTrue,
        );
        expect(hiragana, isNot(contains('ゔ')));
        if (raw['group'] == 'contracted') {
          expect(hiragana.runes, hasLength(2));
          expect(firstContracted, contains(hiragana[0]));
          expect('ゃゅょ', contains(hiragana[1]));
        } else {
          expect(hiragana.runes, hasLength(1));
        }
      }
    },
  );

  test('every target constituent has an original numbered stroke diagram', () {
    final requiredRunes = items.expand((item) => item.glyph.runes).toSet();
    expect(requiredRunes, hasLength(251));
    for (final rune in requiredRunes) {
      final hex = rune.toRadixString(16).padLeft(5, '0');
      final file = File('assets/strokes/$hex.svg');
      expect(file.existsSync(), isTrue, reason: hex);
      final svg = file.readAsStringSync();
      expect(svg, contains('<svg'));
      expect(svg, contains('<path'));
      expect(svg, contains('StrokePaths'));
      expect(svg, contains('StrokeNumbers'));
      expect(svg, contains('Ulrich Apel'));
    }
  });

  test(
    'drawing shape equivalents are explicit, symmetric, and typing stays strict',
    () {
      for (final item in items) {
        for (final alias in item.drawingAliases) {
          expect(Grader.drawing(item, [alias]), ReviewOutcome.correct);
          expect(
            Grader.typed(item, PracticeSkill.typing, alias),
            ReviewOutcome.incorrect,
          );
          for (final counterpart in items.where(
            (other) => other.glyph == alias,
          )) {
            expect(
              counterpart.drawingAliases,
              contains(item.glyph),
              reason: '${item.glyph}/$alias',
            );
          }
        }
      }
    },
  );

  test('provenance and all redistributed data licenses are included', () {
    final sources =
        jsonDecode(File('assets/curriculum/sources.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final name in ['kanjidic2', 'jmdict']) {
      final source = sources[name] as Map<String, dynamic>;
      expect(source['dateOfCreation'], matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(source['sha256'], matches(r'^[a-f0-9]{64}$'));
      expect(source['license'], 'CC-BY-SA-4.0');
    }
    expect((sources['kanjivg'] as Map)['commit'], matches(r'^[a-f0-9]{40}$'));
    for (final path in [
      'NOTICE.txt',
      'CC-BY-SA-4.0.txt',
      'KanjiVG-COPYING.txt',
      'EDRDG-licence.html',
      'KANJIDIC2-documentation.html',
    ]) {
      expect(File('assets/licenses/$path').lengthSync(), greaterThan(1000));
    }
  });
}
