enum ScriptKind { hiragana, katakana, kanji }

enum PracticeSkill { reading, typing, drawing }

enum LessonScope { hiragana, katakana, kanji, mixed }

enum LessonFocus { balanced, reading, typing, drawing }

enum ReviewOutcome { correct, incorrect, revealed, neutral }

T _enumValue<T extends Enum>(List<T> values, Object? value) =>
    values.firstWhere((entry) => entry.name == value);

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

List<String> _strings(Object? value) =>
    value == null ? const [] : List<String>.from(value as List);

/// A curriculum target. A target may be a kana pair (きゃ), not just one codepoint.
class LearningItem {
  const LearningItem({
    required this.id,
    required this.script,
    required this.glyph,
    this.romaji = '',
    this.romajiAliases = const [],
    this.readingKana,
    this.meaning = '',
    this.contextWord,
    this.contextReading,
    this.contextMeaning,
    this.productionCue,
    this.order = 0,
    this.frequencyRank,
    this.drawingAliases = const [],
    bool? gateRequired,
    this.contextual = false,
  }) : gateRequired = gateRequired ?? (script != ScriptKind.kanji);

  final String id;
  final ScriptKind script;
  final String glyph;
  final String romaji;
  final List<String> romajiAliases;
  final String? readingKana;
  final String meaning;
  final String? contextWord;
  final String? contextReading;
  final String? contextMeaning;
  final String? productionCue;
  final int order;
  final int? frequencyRank;

  /// Only genuine shape equivalents, e.g. カ/力. Never typing aliases.
  final List<String> drawingAliases;
  final bool gateRequired;

  /// Symbols with no independent sound are read in a short contextual snippet.
  final bool contextual;

  bool get isKanji => script == ScriptKind.kanji;
  String get scriptLabel => switch (script) {
    ScriptKind.hiragana => 'hiragana',
    ScriptKind.katakana => 'katakana',
    ScriptKind.kanji => 'kanji',
  };

  factory LearningItem.fromJson(Map<String, dynamic> json) => LearningItem(
    id: json['id'] as String,
    script: _enumValue(ScriptKind.values, json['script']),
    glyph: json['glyph'] as String,
    romaji: json['romaji'] as String? ?? '',
    romajiAliases: _strings(json['romajiAliases'] ?? json['acceptedRomaji']),
    readingKana: json['readingKana'] as String?,
    meaning: json['meaning'] as String? ?? '',
    contextWord: json['contextWord'] as String?,
    contextReading: json['contextReading'] as String?,
    contextMeaning: json['contextMeaning'] as String?,
    productionCue: json['productionCue'] as String?,
    order: (json['order'] as num?)?.toInt() ?? 0,
    frequencyRank: (json['frequencyRank'] as num?)?.toInt(),
    drawingAliases: _strings(json['drawingAliases']),
    gateRequired: json['gateRequired'] as bool?,
    contextual: json['contextual'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'script': script.name,
    'glyph': glyph,
    'romaji': romaji,
    'romajiAliases': romajiAliases,
    'readingKana': readingKana,
    'meaning': meaning,
    'contextWord': contextWord,
    'contextReading': contextReading,
    'contextMeaning': contextMeaning,
    'productionCue': productionCue,
    'order': order,
    'frequencyRank': frequencyRank,
    'drawingAliases': drawingAliases,
    'gateRequired': gateRequired,
    'contextual': contextual,
  };
}

/// One independently scheduled skill for one curriculum target.
class SkillProgress {
  const SkillProgress({
    required this.itemId,
    required this.skill,
    this.successfulReviews = 0,
    this.dueAt,
    this.lastAdvancedDate,
    this.lastAttemptAt,
    this.lastIncorrectAt,
    this.correctCount = 0,
    this.incorrectCount = 0,
  });

  final String itemId;
  final PracticeSkill skill;
  final int successfulReviews;
  final DateTime? dueAt;
  final String? lastAdvancedDate;
  final DateTime? lastAttemptAt;
  final DateTime? lastIncorrectAt;
  final int correctCount;
  final int incorrectCount;

  String get key => keyFor(itemId, skill);
  static String keyFor(String itemId, PracticeSkill skill) =>
      '$itemId:${skill.name}';
  bool get mastered => successfulReviews >= 3;
  bool get struggling => lastIncorrectAt != null && !mastered;
  bool isDue(DateTime now) => dueAt == null || !dueAt!.isAfter(now);

  factory SkillProgress.fromJson(Map<String, dynamic> json) => SkillProgress(
    itemId: json['itemId'] as String,
    skill: _enumValue(PracticeSkill.values, json['skill']),
    successfulReviews: (json['successfulReviews'] as num?)?.toInt() ?? 0,
    dueAt: _date(json['dueAt']),
    lastAdvancedDate: json['lastAdvancedDate'] as String?,
    lastAttemptAt: _date(json['lastAttemptAt']),
    lastIncorrectAt: _date(json['lastIncorrectAt']),
    correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
    incorrectCount: (json['incorrectCount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'skill': skill.name,
    'successfulReviews': successfulReviews,
    'dueAt': dueAt?.toIso8601String(),
    'lastAdvancedDate': lastAdvancedDate,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'lastIncorrectAt': lastIncorrectAt?.toIso8601String(),
    'correctCount': correctCount,
    'incorrectCount': incorrectCount,
  };
}

class ReviewAttempt {
  const ReviewAttempt({
    required this.questionId,
    required this.itemId,
    required this.skill,
    required this.outcome,
    required this.answeredAt,
    this.response = '',
    this.assisted = false,
  });

  final String questionId;
  final String itemId;
  final PracticeSkill skill;
  final ReviewOutcome outcome;
  final DateTime answeredAt;
  final String response;
  final bool assisted;

  factory ReviewAttempt.fromJson(Map<String, dynamic> json) => ReviewAttempt(
    questionId: json['questionId'] as String,
    itemId: json['itemId'] as String,
    skill: _enumValue(PracticeSkill.values, json['skill']),
    outcome: _enumValue(ReviewOutcome.values, json['outcome']),
    answeredAt: DateTime.parse(json['answeredAt'] as String),
    response: json['response'] as String? ?? '',
    assisted: json['assisted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'itemId': itemId,
    'skill': skill.name,
    'outcome': outcome.name,
    'answeredAt': answeredAt.toIso8601String(),
    'response': response,
    'assisted': assisted,
  };
}

class LessonQuestion {
  const LessonQuestion({
    required this.id,
    required this.itemId,
    required this.skill,
  });

  final String id;
  final String itemId;
  final PracticeSkill skill;

  String displayFor(LearningItem item) {
    if (skill == PracticeSkill.reading) {
      return item.contextual ? item.contextWord ?? item.glyph : item.glyph;
    }
    return item.isKanji ? item.readingKana ?? '' : item.romaji;
  }

  String promptFor(LearningItem item) {
    if (skill == PracticeSkill.reading) {
      return item.isKanji
          ? 'Type the taught reading in hiragana.'
          : item.contextual
          ? 'Type the sound of this example in English letters.'
          : 'Type the sound in English letters.';
    }
    final action = skill == PracticeSkill.drawing ? 'Draw' : 'Type';
    final cue = item.productionCue;
    return '$action the ${item.scriptLabel}${item.isKanji ? ' character' : ''}.'
        '${cue == null || cue.isEmpty ? '' : ' $cue'}';
  }

  String expectedAnswerFor(LearningItem item) => skill != PracticeSkill.reading
      ? item.glyph
      : item.isKanji
      ? item.readingKana ?? ''
      : item.romaji;

  factory LessonQuestion.fromJson(Map<String, dynamic> json) => LessonQuestion(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    skill: _enumValue(PracticeSkill.values, json['skill']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'skill': skill.name,
  };
}

class LessonSession {
  const LessonSession({
    required this.id,
    required this.scope,
    required this.focus,
    required this.questions,
    required this.startedAt,
    this.currentIndex = 0,
    this.attempts = const [],
  });

  final String id;
  final LessonScope scope;
  final LessonFocus focus;
  final List<LessonQuestion> questions;
  final DateTime startedAt;
  final int currentIndex;
  final List<ReviewAttempt> attempts;
  bool get isComplete => currentIndex >= questions.length;
  LessonQuestion? get currentQuestion =>
      isComplete ? null : questions[currentIndex];
  int get correctCount =>
      attempts.where((a) => a.outcome == ReviewOutcome.correct).length;
  int get gradedCount =>
      attempts.where((a) => a.outcome != ReviewOutcome.neutral).length;

  LessonSession copyWith({int? currentIndex, List<ReviewAttempt>? attempts}) =>
      LessonSession(
        id: id,
        scope: scope,
        focus: focus,
        questions: questions,
        startedAt: startedAt,
        currentIndex: currentIndex ?? this.currentIndex,
        attempts: attempts ?? this.attempts,
      );

  LessonSession advance() =>
      isComplete ? this : copyWith(currentIndex: currentIndex + 1);

  /// Neutral recognition attempts keep the same question active.
  LessonSession withAttempt(ReviewAttempt attempt, {bool advance = true}) {
    if (isComplete ||
        attempt.questionId != currentQuestion!.id ||
        attempt.itemId != currentQuestion!.itemId ||
        attempt.skill != currentQuestion!.skill) {
      throw StateError('Attempt does not belong to the active question.');
    }
    return copyWith(
      currentIndex: advance && attempt.outcome != ReviewOutcome.neutral
          ? currentIndex + 1
          : currentIndex,
      attempts: [...attempts, attempt],
    );
  }

  factory LessonSession.fromJson(Map<String, dynamic> json) => LessonSession(
    id: json['id'] as String,
    scope: _enumValue(LessonScope.values, json['scope']),
    focus: _enumValue(LessonFocus.values, json['focus']),
    questions: (json['questions'] as List)
        .map(
          (q) => LessonQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
        )
        .toList(growable: false),
    startedAt: DateTime.parse(json['startedAt'] as String),
    currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
    attempts: (json['attempts'] as List? ?? [])
        .map((a) => ReviewAttempt.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'scope': scope.name,
    'focus': focus.name,
    'questions': questions.map((q) => q.toJson()).toList(),
    'startedAt': startedAt.toIso8601String(),
    'currentIndex': currentIndex,
    'attempts': attempts.map((a) => a.toJson()).toList(),
  };
}
