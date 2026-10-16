import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'labels.dart';
import 'lesson_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'ui_contract.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final LearningController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LessonScope _scope = LessonScope.hiragana;
  LessonFocus _focus = LessonFocus.balanced;

  Future<void> _start() async {
    final controller = widget.controller;
    final session = controller.activeSession;
    if (session != null && !session.isComplete) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('You have a lesson in progress'),
          content: const Text(
            'Resume where you left off, or start this lesson with a fresh set of questions. Your completed answers stay saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Resume lesson'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (replace == null || !mounted) return;
      if (!replace) {
        await _openLesson();
        return;
      }
      await controller.abandonLesson();
    }
    await controller.startLesson(_scope, _focus);
    if (mounted && controller.activeSession != null) await _openLesson();
  }

  Future<void> _openLesson() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LessonScreen(controller: widget.controller),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final items = controller.curriculum
        .where(
          (item) => controller.kanjiUnlocked || item.script != ScriptKind.kanji,
        )
        .toList();
    final now = DateTime.now();
    final due = controller.progress.values
        .where((p) => p.dueAt != null && !p.dueAt!.isAfter(now))
        .length;
    final mastered = items
        .where(
          (item) => [PracticeSkill.reading, PracticeSkill.typing].every(
            (skill) =>
                controller.progress['${item.id}:${skill.name}']?.mastered ??
                false,
          ),
        )
        .length;
    final session = controller.activeSession;
    return SingleChildScrollView(
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xff424581),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ONE CHARACTER AT A TIME',
                          style: TextStyle(
                            color: Color(0xffd4d5f7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Small steps.\nNew worlds.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Build a little Japanese\ninto every day.',
                          style: TextStyle(
                            color: Color(0xffdedff6),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Transform.rotate(
                      angle: -.12,
                      child: Container(
                        width: 88,
                        height: 112,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xfff6eee0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'あ',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: Color(0xff424581),
                            fontSize: 76,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    value: '$due',
                    label: 'reviews due',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    value: '$mastered',
                    label: 'items mastered',
                    icon: Icons.spa_outlined,
                  ),
                ),
              ],
            ),
            if (session != null && !session.isComplete) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.play_circle_outline,
                    color: colors.primary,
                  ),
                  title: const Text(
                    'Pick up where you left off',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${scopeLabel(session.scope)} · ${session.currentIndex} of ${session.questions.length} complete',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: controller.busy ? null : _openLesson,
                ),
              ),
            ],
            const SizedBox(height: 30),
            const Text(
              'Choose your path',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Ten small questions. Lasting progress.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: LessonScope.values
                    .map(
                      (scope) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _ScriptTile(
                          scope: scope,
                          selected: _scope == scope,
                          locked:
                              scope == LessonScope.kanji &&
                              !controller.kanjiUnlocked,
                          onTap: () {
                            if (scope == LessonScope.kanji &&
                                !controller.kanjiUnlocked) {
                              showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Your kanji path is ahead'),
                                  content: const Text(
                                    'Master reading and typing for basic kana, voiced sounds, and combinations in both scripts to unlock kanji. Drawing is optional for this milestone. Once unlocked, kanji stays available.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Got it'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              setState(() => _scope = scope);
                            }
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<LessonFocus>(
              initialValue: _focus,
              decoration: const InputDecoration(
                labelText: 'Practice focus',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
              items: LessonFocus.values
                  .map(
                    (focus) => DropdownMenuItem(
                      value: focus,
                      child: Text(focusLabel(focus)),
                    ),
                  )
                  .toList(),
              onChanged: (focus) {
                if (focus != null) setState(() => _focus = focus);
              },
            ),
            if (_focus == LessonFocus.drawing &&
                controller.modelStatus != HandwritingModelStatus.ready) ...[
              const SizedBox(height: 16),
              HandwritingModelCard(controller: controller),
            ],
            if (_focus == LessonFocus.balanced &&
                controller.modelStatus != HandwritingModelStatus.ready) ...[
              const SizedBox(height: 12),
              Text(
                'Reading and typing are ready. Download handwriting in Settings to add drawing to balanced lessons.',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    controller.busy ||
                        controller.curriculum.isEmpty ||
                        (_focus == LessonFocus.drawing &&
                            controller.modelStatus !=
                                HandwritingModelStatus.ready)
                    ? null
                    : _start,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  controller.busy
                      ? 'Preparing lesson…'
                      : 'Start ${scopeLabel(_scope).toLowerCase()}',
                ),
              ),
            ),
            if (_scope == LessonScope.mixed && !controller.kanjiUnlocked) ...[
              const SizedBox(height: 10),
              Text(
                'Mixed practice includes both kana scripts. Kanji joins when unlocked.',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 30),
            const Text(
              'Your growing skills',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: PracticeSkill.values.map((skill) {
                    final count = items
                        .where(
                          (item) =>
                              controller
                                  .progress['${item.id}:${skill.name}']
                                  ?.mastered ??
                              false,
                        )
                        .length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  skillLabel(skill),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '$count / ${items.length}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: items.isEmpty ? 0 : count / items.length,
                              minHeight: 7,
                              backgroundColor: colors.surfaceContainerHighest,
                              color: skill == PracticeSkill.drawing
                                  ? const Color(0xffc77963)
                                  : colors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Mastery grows through correct reviews on separate days. Mistakes help us choose what to practice next.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.5,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScriptTile extends StatelessWidget {
  const _ScriptTile({
    required this.scope,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final LessonScope scope;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final glyph = switch (scope) {
      LessonScope.hiragana => 'あ',
      LessonScope.katakana => 'ア',
      LessonScope.kanji => '漢',
      LessonScope.mixed => 'あ ア',
    };
    final subtitle = switch (scope) {
      LessonScope.hiragana => 'Start with the essentials',
      LessonScope.katakana => 'A new shape for each sound',
      LessonScope.kanji =>
        locked ? 'Unlock through kana' : '100 frequent characters',
      LessonScope.mixed => 'Bring your skills together',
    };
    return Semantics(
      selected: selected,
      button: true,
      label: '${scopeLabel(scope)}${locked ? ", locked" : ""}',
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .55)
            : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: .5),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        glyph,
                        style: TextStyle(
                          fontSize: scope == LessonScope.mixed ? 27 : 34,
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (locked)
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      )
                    else if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  scopeLabel(scope),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
