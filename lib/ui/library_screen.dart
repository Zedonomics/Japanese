import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'labels.dart';
import 'stroke_diagram.dart';
import 'theme.dart';
import 'ui_contract.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.controller});
  final LearningController controller;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  ScriptKind? _script = ScriptKind.hiragana;
  String _search = '';
  bool _strugglingOnly = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = widget.controller.curriculum.where((item) {
      if (_script != null && item.script != _script) return false;
      if (_strugglingOnly &&
          !PracticeSkill.values.any(
            (skill) =>
                widget
                    .controller
                    .progress[SkillProgress.keyFor(item.id, skill)]
                    ?.struggling ??
                false,
          )) {
        return false;
      }
      return '${item.glyph} ${item.romaji} ${item.readingKana ?? ''} ${item.meaning} ${item.contextWord ?? ''}'
          .toLowerCase()
          .contains(_search.toLowerCase());
    }).toList();
    return SingleChildScrollView(
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your character library',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Meet a character. Notice its shape. Watch it become familiar.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 22),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Find a sound, character, or meaning',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _script == null,
                  onSelected: (_) => setState(() => _script = null),
                ),
                ...ScriptKind.values.map(
                  (script) => ChoiceChip(
                    label: Text(scriptLabel(script)),
                    selected: _script == script,
                    onSelected: (_) => setState(() => _script = script),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FilterChip(
              avatar: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Needs more practice'),
              selected: _strugglingOnly,
              onSelected: (value) => setState(() => _strugglingOnly = value),
            ),
            const SizedBox(height: 18),
            Text(
              '${items.length} learning items',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('No characters match. Try a different filter.'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 500 ? 5 : 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: items.map((item) {
                      final skills = PracticeSkill.values
                          .map(
                            (skill) =>
                                widget.controller.progress[SkillProgress.keyFor(
                                  item.id,
                                  skill,
                                )],
                          )
                          .toList();
                      final learned = skills
                          .where((p) => p?.mastered ?? false)
                          .length;
                      final struggling = skills.any(
                        (p) => p?.struggling ?? false,
                      );
                      return SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 10) /
                            columns,
                        child: Semantics(
                          label:
                              '${item.glyph}, ${item.isKanji ? item.readingKana : item.romaji}, $learned of 3 skills mastered',
                          button: true,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => showCharacterDetail(
                                context,
                                item,
                                widget.controller,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 15,
                                ),
                                child: Column(
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item.glyph,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: item.glyph.runes.length > 1
                                              ? 29
                                              : 38,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.isKanji
                                          ? item.readingKana ?? ''
                                          : item.contextual
                                          ? 'Example:\n${item.romaji}'
                                          : item.romaji,
                                      maxLines: item.contextual ? 2 : 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        3,
                                        (index) => Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                skills[index]?.mastered == true
                                                ? colors.primary
                                                : (struggling &&
                                                          skills[index]
                                                                  ?.struggling ==
                                                              true
                                                      ? const Color(0xffc77963)
                                                      : colors.outlineVariant),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            const SizedBox(height: 20),
            Text(
              'Dots show reading, typing, and drawing mastery, in that order. Kanji uses a newspaper frequency ranking; each item teaches one reading in context.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCharacterDetail(
  BuildContext context,
  LearningItem item,
  LearningController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: .83,
    minChildSize: .45,
    maxChildSize: .95,
    expand: false,
    builder: (context, scrollController) => SingleChildScrollView(
      controller: scrollController,
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                scriptLabel(item.script).toUpperCase(),
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                item.glyph,
                style: const TextStyle(fontSize: 94, height: 1.3),
              ),
            ),
            Center(
              child: Text(
                item.isKanji
                    ? item.readingKana ?? ''
                    : item.contextual
                    ? 'Example: ${item.romaji}'
                    : item.romaji,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (item.contextual) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'This symbol has no standalone sound.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (item.meaning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  item.meaning,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (item.productionCue?.isNotEmpty ?? false) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.productionCue!,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (item.contextWord != null) ...[
              const SizedBox(height: 22),
              const Text(
                'In context',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(item.contextWord!, style: const TextStyle(fontSize: 30)),
              if (item.contextReading != null)
                Text(
                  item.contextReading!,
                  style: const TextStyle(fontSize: 17),
                ),
              if (item.contextMeaning != null)
                Text(
                  item.contextMeaning!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (item.isKanji)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Practice covers this taught reading. Other readings can be learned later.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Your progress',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...PracticeSkill.values.map((skill) {
              final progress =
                  controller.progress[SkillProgress.keyFor(item.id, skill)];
              final total =
                  (progress?.correctCount ?? 0) +
                  (progress?.incorrectCount ?? 0);
              final status = progress == null
                  ? 'Not practiced yet'
                  : progress.mastered
                  ? 'Mastered'
                  : '${progress.successfulReviews} / 3 spaced successes';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(skillLabel(skill)),
                subtitle: Text(
                  total == 0
                      ? status
                      : '$status · ${progress!.correctCount}/$total correct',
                ),
                trailing: Icon(
                  progress?.mastered == true
                      ? Icons.check_circle
                      : progress?.struggling == true
                      ? Icons.refresh
                      : Icons.circle_outlined,
                  color: progress?.mastered == true
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              );
            }),
            const SizedBox(height: 12),
            StrokeGuide(glyph: item.glyph),
            if (item.frequencyRank != null) ...[
              const SizedBox(height: 20),
              Text(
                'Newspaper frequency rank: ${item.frequencyRank}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);

class StrokeGuide extends StatefulWidget {
  const StrokeGuide({super.key, required this.glyph});
  final String glyph;

  @override
  State<StrokeGuide> createState() => _StrokeGuideState();
}

class _StrokeGuideState extends State<StrokeGuide> {
  bool _show = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: () => setState(() => _show = !_show),
        icon: Icon(
          _show ? Icons.visibility_off_outlined : Icons.gesture_rounded,
        ),
        label: Text(_show ? 'Hide stroke guide' : 'Show stroke guide'),
      ),
      if (_show) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.glyph.runes
              .map(
                (rune) => Container(
                  width: 136,
                  height: 136,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: StrokeDiagram(rune: rune),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        Text(
          'Follow the numbered strokes. Handwriting practice checks character identity; stroke order does not affect your score.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}
