import '../domain/domain.dart';

String scriptLabel(ScriptKind script) => switch (script) {
  ScriptKind.hiragana => 'Hiragana',
  ScriptKind.katakana => 'Katakana',
  ScriptKind.kanji => 'Kanji',
};

String scopeLabel(LessonScope scope) => switch (scope) {
  LessonScope.hiragana => 'Hiragana',
  LessonScope.katakana => 'Katakana',
  LessonScope.kanji => 'Kanji',
  LessonScope.mixed => 'Mixed practice',
};

String skillLabel(PracticeSkill skill) => switch (skill) {
  PracticeSkill.reading => 'Reading',
  PracticeSkill.typing => 'Typing',
  PracticeSkill.drawing => 'Drawing',
};

String focusLabel(LessonFocus focus) => switch (focus) {
  LessonFocus.balanced => 'All skills',
  LessonFocus.reading => 'Reading',
  LessonFocus.typing => 'Typing',
  LessonFocus.drawing => 'Drawing',
};
