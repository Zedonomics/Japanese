import 'models.dart';

class _Candidate {
  const _Candidate(this.item, this.skill, this.progress);
  final LearningItem item;
  final PracticeSkill skill;
  final SkillProgress? progress;
}

class LessonEngine {
  const LessonEngine();

  LessonSession build({
    required List<LearningItem> items,
    required Map<String, SkillProgress> progress,
    required LessonScope scope,
    LessonFocus focus = LessonFocus.balanced,
    required bool kanjiUnlocked,
    required DateTime now,
    int length = 10,
    bool drawingAvailable = true,
  }) {
    if (length < 1) {
      throw ArgumentError.value(length, 'length', 'Must be positive');
    }
    final eligible =
        items.where((item) {
          if (item.isKanji && !kanjiUnlocked) {
            return false;
          }
          return scope == LessonScope.mixed || item.script.name == scope.name;
        }).toList()..sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
        });
    final skills = focus == LessonFocus.balanced
        ? PracticeSkill.values
              .where(
                (skill) => drawingAvailable || skill != PracticeSkill.drawing,
              )
              .toList()
        : [PracticeSkill.values.byName(focus.name)];
    final knownItems = progress.values.map((p) => p.itemId).toSet();
    final candidates = [
      for (final item in eligible)
        for (final skill in skills)
          _Candidate(
            item,
            skill,
            progress[SkillProgress.keyFor(item.id, skill)],
          ),
    ];
    final due = candidates
        .where((c) => c.progress != null && c.progress!.isDue(now))
        .toList();
    due.sort((a, b) {
      final aError = a.progress!.struggling;
      final bError = b.progress!.struggling;
      if (aError != bError) {
        return aError ? -1 : 1;
      }
      if (aError) {
        final errorOrder = b.progress!.lastIncorrectAt!.compareTo(
          a.progress!.lastIncorrectAt!,
        );
        if (errorOrder != 0) {
          return errorOrder;
        }
      }
      final dueOrder = (a.progress!.dueAt ?? DateTime(1970)).compareTo(
        b.progress!.dueAt ?? DateTime(1970),
      );
      return dueOrder != 0 ? dueOrder : _curriculumOrder(a, b);
    });
    final unstarted = candidates.where((c) => c.progress == null).toList();
    final notDue =
        candidates
            .where((c) => c.progress != null && !c.progress!.isDue(now))
            .toList()
          ..sort((a, b) => a.progress!.dueAt!.compareTo(b.progress!.dueAt!));
    final introduced = <String>{};
    final selected = <_Candidate>[];

    void appendFrom(List<_Candidate> pool) {
      while (pool.isNotEmpty && selected.length < length) {
        final allowed = pool
            .where(
              (candidate) =>
                  knownItems.contains(candidate.item.id) ||
                  introduced.contains(candidate.item.id) ||
                  introduced.length < 3,
            )
            .toList();
        if (allowed.isEmpty) {
          break;
        }
        var chosen = allowed.first;
        if (focus == LessonFocus.balanced) {
          final wanted = skills[selected.length % skills.length];
          chosen = allowed.firstWhere(
            (c) => c.skill == wanted,
            orElse: () => allowed.first,
          );
        }
        pool.remove(chosen);
        selected.add(chosen);
        if (!knownItems.contains(chosen.item.id)) {
          introduced.add(chosen.item.id);
        }
      }
    }

    appendFrom(due);
    appendFrom(unstarted);
    appendFrom(notDue);
    // Small/focused curricula still yield a full lesson. Same-day repeats are
    // practice only: ReviewScheduler prevents a second advancement that day.
    final repeatPool = List<_Candidate>.from(selected);
    for (
      var index = 0;
      selected.length < length && repeatPool.isNotEmpty;
      index++
    ) {
      selected.add(repeatPool[index % repeatPool.length]);
    }
    final sessionId = 'lesson-${now.microsecondsSinceEpoch}';
    return LessonSession(
      id: sessionId,
      scope: scope,
      focus: focus,
      startedAt: now,
      questions: [
        for (var index = 0; index < selected.length; index++)
          LessonQuestion(
            id: '$sessionId-$index',
            itemId: selected[index].item.id,
            skill: selected[index].skill,
          ),
      ],
    );
  }

  static int _curriculumOrder(_Candidate a, _Candidate b) {
    final order = a.item.order.compareTo(b.item.order);
    if (order != 0) {
      return order;
    }
    final id = a.item.id.compareTo(b.item.id);
    return id != 0 ? id : a.skill.index.compareTo(b.skill.index);
  }
}
