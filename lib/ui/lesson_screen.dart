import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'drawing_pad.dart';
import 'labels.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'ui_contract.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.controller});
  final LearningController controller;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _introIndex = 0;

  Future<void> _leave() async {
    await widget.controller.exitLesson();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final session = controller.activeSession;
      final intros = controller.introItems;
      final introducing = intros.isNotEmpty;
      return PopScope(
        canPop: !controller.busy,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) controller.exitLesson();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: controller.busy ? null : _leave,
              tooltip: 'Save and leave lesson',
              icon: const Icon(Icons.close_rounded),
            ),
            title: Text(
              introducing
                  ? 'Meet your new characters'
                  : session == null
                  ? 'Practice'
                  : scopeLabel(session.scope),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (session != null && !introducing && !session.isComplete)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Center(
                    child: Text(
                      '${session.currentIndex + 1} / ${session.questions.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (session != null && !introducing)
                  LinearProgressIndicator(
                    value: session.questions.isEmpty
                        ? 0
                        : session.currentIndex / session.questions.length,
                    minHeight: 4,
                  ),
                if (controller.error != null)
                  MaterialBanner(
                    content: Text(controller.error!),
                    actions: [
                      TextButton(
                        onPressed: controller.clearError,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                Expanded(
                  child: session == null
                      ? Center(
                          child: FilledButton(
                            onPressed: _leave,
                            child: const Text('Back to learning'),
                          ),
                        )
                      : introducing
                      ? _Introduction(
                          item: intros[_introIndex.clamp(0, intros.length - 1)],
                          index: _introIndex,
                          count: intros.length,
                          onNext: () {
                            if (_introIndex + 1 < intros.length) {
                              setState(() => _introIndex++);
                            } else {
                              controller.completeIntroduction();
                            }
                          },
                        )
                      : session.isComplete
                      ? _LessonSummary(session: session, onDone: _leave)
                      : _Question(
                          key: ValueKey(session.currentQuestion!.id),
                          controller: controller,
                          question: session.currentQuestion!,
                          item: controller.curriculum.firstWhere(
                            (item) =>
                                item.id == session.currentQuestion!.itemId,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Introduction extends StatelessWidget {
  const _Introduction({
    required this.item,
    required this.index,
    required this.count,
    required this.onNext,
  });
  final LearningItem item;
  final int index;
  final int count;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEW CHARACTER ${index + 1} OF $count',
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Take a moment to notice.',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Text(
                      scriptLabel(item.script).toUpperCase(),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 1.5,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.glyph,
                      style: TextStyle(
                        fontSize: item.glyph.runes.length > 1 ? 76 : 110,
                        height: 1.4,
                      ),
                    ),
                    Text(
                      item.isKanji
                          ? item.readingKana ?? ''
                          : item.contextual
                          ? 'Example: ${item.romaji}'
                          : item.romaji,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: item.contextual ? 22 : 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.contextual) ...[
                      const SizedBox(height: 8),
                      Text(
                        'This symbol has no standalone sound.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (item.meaning.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        item.meaning,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (item.productionCue?.isNotEmpty ?? false) ...[
              const SizedBox(height: 18),
              Text(
                item.productionCue!,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ],
            if (item.contextWord != null) ...[
              const SizedBox(height: 18),
              Text(
                '${item.contextWord}  ·  ${item.contextReading ?? ''}',
                style: const TextStyle(fontSize: 22),
              ),
              if (item.contextMeaning != null)
                Text(
                  item.contextMeaning!,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
            ],
            const SizedBox(height: 22),
            StrokeGuide(key: ValueKey(item.id), glyph: item.glyph),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNext,
                label: Text(
                  index + 1 == count ? 'Let’s practice' : 'Next character',
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'You can revisit this in the character library.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatefulWidget {
  const _Question({
    super.key,
    required this.controller,
    required this.question,
    required this.item,
  });
  final LearningController controller;
  final LessonQuestion question;
  final LearningItem item;

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _drawingKey = GlobalKey<DrawingPadState>();
  bool _hasInk = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_inputChanged);
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _input.removeListener(_inputChanged);
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _composing =>
      _input.value.composing.isValid && !_input.value.composing.isCollapsed;

  Future<void> _submit() async {
    if (widget.controller.busy || _composing) return;
    if (widget.question.skill == PracticeSkill.drawing) {
      final ink = _drawingKey.currentState?.submission;
      if (ink != null && ink.strokes.isNotEmpty) {
        await widget.controller.submitDrawing(ink);
      }
    } else if (_input.text.trim().isNotEmpty) {
      _focus.unfocus();
      await widget.controller.submitText(_input.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final item = widget.item;
    final question = widget.question;
    final feedback = controller.feedback;
    final drawing = question.skill == PracticeSkill.drawing;
    final canAnswer = feedback == null && !controller.busy;
    final romajiAnswer =
        question.skill == PracticeSkill.reading && !item.isKanji;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (question.skill) {
                    PracticeSkill.reading => Icons.visibility_outlined,
                    PracticeSkill.typing => Icons.keyboard_outlined,
                    PracticeSkill.drawing => Icons.gesture_rounded,
                  },
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${skillLabel(question.skill).toUpperCase()} · ${scriptLabel(item.script).toUpperCase()}',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              question.promptFor(item),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 26,
                ),
                child: Column(
                  children: [
                    if (question.skill == PracticeSkill.reading &&
                        item.isKanji &&
                        item.contextWord != null)
                      _HighlightedContext(item: item)
                    else
                      Text(
                        question.displayFor(item),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: question.skill == PracticeSkill.reading
                              ? 82
                              : 48,
                          height: 1.4,
                          fontWeight: question.skill == PracticeSkill.reading
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    if (item.isKanji &&
                        (question.skill == PracticeSkill.reading
                            ? item.contextMeaning != null
                            : item.meaning.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Text(
                        question.skill == PracticeSkill.reading
                            ? item.contextMeaning!
                            : item.meaning,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    if (item.isKanji &&
                        question.skill == PracticeSkill.reading) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Read the highlighted character.',
                        style: TextStyle(color: colors.primary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (drawing)
              if (controller.modelStatus == HandwritingModelStatus.ready)
                DrawingPad(
                  key: _drawingKey,
                  cells: item.glyph.runes.length,
                  enabled: canAnswer,
                  onChanged: (value) => setState(() => _hasInk = value),
                )
              else
                HandwritingModelCard(controller: controller)
            else ...[
              TextField(
                controller: _input,
                focusNode: _focus,
                enabled: canAnswer,
                autocorrect: false,
                enableSuggestions: !romajiAnswer,
                textCapitalization: TextCapitalization.none,
                keyboardType: romajiAnswer
                    ? TextInputType.visiblePassword
                    : TextInputType.text,
                textInputAction: TextInputAction.done,
                style: TextStyle(fontSize: romajiAnswer ? 24 : 30),
                decoration: InputDecoration(
                  labelText: romajiAnswer
                      ? 'Romaji answer'
                      : item.isKanji && question.skill == PracticeSkill.reading
                      ? 'Reading in hiragana'
                      : '${scriptLabel(item.script)} answer',
                  hintText: romajiAnswer
                      ? 'Type the sound…'
                      : 'Use your Japanese keyboard',
                  helperText: _composing
                      ? 'Finish choosing characters on your keyboard first.'
                      : romajiAnswer
                      ? 'Common romaji alternatives are accepted.'
                      : 'Commit the keyboard conversion before submitting.',
                  helperMaxLines: 3,
                ),
                // Flutter's default completion clears composition before calling
                // onSubmitted. Preserve it so an IME conversion cannot be graded
                // merely because the keyboard sent a "done" action.
                onEditingComplete: () {
                  if (!_composing) _focus.unfocus();
                },
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 22),
            if (feedback != null) ...[
              _FeedbackCard(feedback: feedback, question: question, item: item),
              const SizedBox(height: 16),
              if (feedback.outcome == ReviewOutcome.neutral)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () {
                            _drawingKey.currentState?.clear();
                            controller.retryAnswer();
                          },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.busy ? null : controller.advance,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue'),
                  ),
                ),
              if (feedback.outcome != ReviewOutcome.neutral) ...[
                const SizedBox(height: 12),
                StrokeGuide(glyph: item.glyph),
              ],
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      canAnswer &&
                          !_composing &&
                          (drawing
                              ? _hasInk &&
                                    controller.modelStatus ==
                                        HandwritingModelStatus.ready
                              : _input.text.trim().isNotEmpty)
                      ? _submit
                      : null,
                  child: controller.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Check answer'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed:
                      canAnswer &&
                          (!drawing ||
                              controller.modelStatus ==
                                  HandwritingModelStatus.ready)
                      ? controller.revealAnswer
                      : null,
                  child: const Text('I’m not sure · show answer'),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _HighlightedContext extends StatelessWidget {
  const _HighlightedContext({required this.item});
  final LearningItem item;

  @override
  Widget build(BuildContext context) {
    final word = item.contextWord!;
    final index = word.indexOf(item.glyph);
    if (index < 0) {
      return Text(item.glyph, style: const TextStyle(fontSize: 76));
    }
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: word.substring(0, index)),
          TextSpan(
            text: item.glyph,
            style: TextStyle(
              color: colors.primary,
              decoration: TextDecoration.underline,
              decorationColor: colors.primary.withValues(alpha: .4),
              decorationThickness: 2,
            ),
          ),
          TextSpan(text: word.substring(index + item.glyph.length)),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 58,
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.feedback,
    required this.question,
    required this.item,
  });
  final AnswerFeedback feedback;
  final LessonQuestion question;
  final LearningItem item;

  @override
  Widget build(BuildContext context) {
    final correct = feedback.outcome == ReviewOutcome.correct;
    final neutral = feedback.outcome == ReviewOutcome.neutral;
    final colors = Theme.of(context).colorScheme;
    final title = switch (feedback.outcome) {
      ReviewOutcome.correct => 'Well remembered.',
      ReviewOutcome.incorrect => 'Keep this one close.',
      ReviewOutcome.revealed => 'A new chance to learn.',
      ReviewOutcome.neutral => 'Let’s try that shape again.',
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: correct
              ? colors.primaryContainer.withValues(alpha: .5)
              : colors.tertiaryContainer.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct
                      ? Icons.check_circle_outline
                      : neutral
                      ? Icons.gesture_rounded
                      : Icons.lightbulb_outline,
                  color: correct ? colors.primary : colors.tertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!neutral) ...[
              Text(
                'Expected answer',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                question.expectedAnswerFor(item),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (feedback.response.isNotEmpty && !correct) ...[
                const SizedBox(height: 8),
                Text(
                  'Your answer: ${feedback.response}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 10),
            ],
            Text(
              feedback.message ??
                  (correct
                      ? 'Your progress has been saved. Spaced reviews help this stay with you.'
                      : neutral
                      ? 'This attempt is ungraded. Clear the cells and write again.'
                      : 'We’ll bring this skill back for another review. Mistakes are part of learning.'),
              style: TextStyle(height: 1.5, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonSummary extends StatelessWidget {
  const _LessonSummary({required this.session, required this.onDone});
  final LessonSession session;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: PageWidth(
        child: Column(
          children: [
            const SizedBox(height: 35),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.spa_outlined, size: 58, color: colors.primary),
            ),
            const SizedBox(height: 28),
            const Text(
              'Another small step.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'You made time for Japanese.\nYour progress is saved on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.7, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '${session.correctCount} / ${session.questions.length}',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const Text('answered correctly without a reveal'),
                    const Divider(height: 32),
                    ...PracticeSkill.values.map((skill) {
                      final attempts = session.attempts
                          .where(
                            (a) =>
                                a.skill == skill &&
                                a.outcome != ReviewOutcome.neutral,
                          )
                          .toList();
                      if (attempts.isEmpty) return const SizedBox.shrink();
                      final correct = attempts
                          .where((a) => a.outcome == ReviewOutcome.correct)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(skillLabel(skill))),
                            Text(
                              '$correct / ${attempts.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('Back to your path'),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Rest is part of remembering. Come back when your next reviews are due.',
              textAlign: TextAlign.center,
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
