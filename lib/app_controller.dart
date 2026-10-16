import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data/progress_repository.dart';
import 'domain/domain.dart';
import 'services/handwriting_service.dart';
import 'ui/ui_contract.dart';

class AppController extends LearningController {
  AppController({
    ProgressRepository? repository,
    HandwritingService? handwriting,
    Future<List<LearningItem>> Function()? curriculumLoader,
    DateTime Function()? now,
    // Keep the injected argument public while the database handle stays private.
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       _handwriting = handwriting ?? MlKitHandwritingService(),
       _curriculumLoader = curriculumLoader ?? _loadBundledCurriculum,
       _now = now ?? DateTime.now;

  ProgressRepository? _repository;
  final HandwritingService _handwriting;
  final Future<List<LearningItem>> Function() _curriculumLoader;
  final DateTime Function() _now;
  List<LearningItem> _curriculum = const [];
  Map<String, SkillProgress> _progress = {};
  LessonSession? _activeSession;
  List<String> _introIds = [];
  AnswerFeedback? _feedback;
  bool _loading = true;
  bool _busy = false;
  bool _kanjiUnlocked = false;
  String? _error;
  HandwritingModelStatus _modelStatus = HandwritingModelStatus.unavailable;
  bool _disposed = false;

  @override
  List<LearningItem> get curriculum => List.unmodifiable(_curriculum);
  @override
  Map<String, SkillProgress> get progress => Map.unmodifiable(_progress);
  @override
  LessonSession? get activeSession => _activeSession;
  @override
  List<LearningItem> get introItems =>
      _curriculum.where((item) => _introIds.contains(item.id)).toList();
  @override
  AnswerFeedback? get feedback => _feedback;
  @override
  bool get loading => _loading;
  @override
  bool get busy => _busy;
  @override
  bool get kanjiUnlocked => _kanjiUnlocked;
  @override
  String? get error => _error;
  @override
  HandwritingModelStatus get modelStatus => _modelStatus;

  static Future<List<LearningItem>> _loadBundledCurriculum() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/curriculum/items.json'))
            as Map<String, dynamic>;
    return (data['items'] as List)
        .map(
          (item) =>
              LearningItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> initialize() async {
    try {
      _curriculum = await _curriculumLoader();
      if (_curriculum.isEmpty ||
          _curriculum.map((item) => item.id).toSet().length !=
              _curriculum.length) {
        throw const FormatException('The bundled curriculum is incomplete.');
      }
      debugPrint('Kana Path startup: curriculum loaded.');
      _repository ??= await ProgressRepository.open();
      await _reload();
      debugPrint('Kana Path startup: progress storage ready.');
      try {
        debugPrint('Kana Path startup: checking handwriting model.');
        // Optional native model detection must not indefinitely delay lessons.
        _modelStatus =
            await _handwriting.isReady().timeout(const Duration(seconds: 5))
            ? HandwritingModelStatus.ready
            : HandwritingModelStatus.unavailable;
        debugPrint(
          'Kana Path startup: handwriting model check finished (${_modelStatus.name}).',
        );
      } catch (_) {
        _modelStatus = HandwritingModelStatus.failed;
        debugPrint('Kana Path startup: handwriting model check failed.');
      }
    } catch (error) {
      _error = 'Could not open your lessons. ${_describe(error)}';
    } finally {
      _loading = false;
      if (_error == null) debugPrint('Kana Path startup: lessons ready.');
      _notify();
    }
  }

  Future<void> _reload() async {
    final state = await _repository!.load();
    _progress = state.progress;
    _kanjiUnlocked = KanjiUnlock.update(
      state.kanjiUnlocked,
      _curriculum,
      _progress,
    );
    if (_kanjiUnlocked != state.kanjiUnlocked) {
      await _repository!.saveUnlock(_kanjiUnlocked);
    }
    _activeSession = state.checkpoint?.session;
    _introIds = state.checkpoint?.introIds ?? [];
    final savedFeedback = state.checkpoint?.feedback;
    _feedback = savedFeedback == null
        ? null
        : AnswerFeedback(
            outcome: ReviewOutcome.values.byName(
              savedFeedback['outcome'] as String,
            ),
            response: savedFeedback['response'] as String,
            message: savedFeedback['message'] as String?,
          );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _loading) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } catch (error) {
      _error = _describe(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  static String _describe(Object error) => switch (error) {
    FormatException(:final message) => message,
    StateError(:final message) => message.toString(),
    TimeoutException() =>
      'Handwriting recognition timed out. Your progress has not changed; please try again.',
    _ =>
      'The operation could not finish. Your saved progress is safe. Please try again.',
  };

  LessonCheckpoint _checkpoint({
    LessonSession? session,
    AnswerFeedback? feedback,
    List<String>? introIds,
  }) => LessonCheckpoint(
    session: session ?? _activeSession!,
    introIds: introIds ?? _introIds,
    feedback: (feedback ?? _feedback) == null
        ? null
        : {
            'outcome': (feedback ?? _feedback)!.outcome.name,
            'response': (feedback ?? _feedback)!.response,
            'message': (feedback ?? _feedback)!.message,
          },
  );

  @override
  Future<void> startLesson(LessonScope scope, LessonFocus focus) =>
      _run(() async {
        if (_activeSession != null && !_activeSession!.isComplete) return;
        if (scope == LessonScope.kanji && !_kanjiUnlocked) {
          throw StateError('Master kana reading and typing to unlock kanji.');
        }
        final session = const LessonEngine().build(
          items: _curriculum,
          progress: _progress,
          scope: scope,
          focus: focus,
          kanjiUnlocked: _kanjiUnlocked,
          now: _now(),
          drawingAvailable: _modelStatus == HandwritingModelStatus.ready,
        );
        if (session.questions.isEmpty) {
          throw StateError('No lessons are available for this selection.');
        }
        final known = _progress.values.map((p) => p.itemId).toSet();
        final introductions = session.questions
            .map((q) => q.itemId)
            .toSet()
            .where((id) => !known.contains(id))
            .toList();
        await _repository!.saveCheckpoint(
          LessonCheckpoint(session: session, introIds: introductions),
        );
        _activeSession = session;
        _introIds = introductions;
        _feedback = null;
      });

  @override
  void completeIntroduction() {
    unawaited(
      _run(() async {
        if (_activeSession == null) return;
        await _repository!.saveCheckpoint(_checkpoint(introIds: []));
        _introIds = [];
      }),
    );
  }

  LearningItem _itemFor(LessonQuestion question) =>
      _curriculum.firstWhere((item) => item.id == question.itemId);

  bool get _canAnswer =>
      _activeSession?.currentQuestion != null &&
      _introIds.isEmpty &&
      (_feedback == null || _feedback!.outcome == ReviewOutcome.neutral);

  @override
  Future<void> submitText(String answer) => _run(() async {
    if (!_canAnswer || answer.trim().isEmpty) return;
    final question = _activeSession!.currentQuestion!;
    if (question.skill == PracticeSkill.drawing) return;
    await _record(
      question,
      Grader.typed(_itemFor(question), question.skill, answer),
      answer,
    );
  });

  @override
  Future<void> submitDrawing(InkSubmission ink) => _run(() async {
    if (!_canAnswer) return;
    final question = _activeSession!.currentQuestion!;
    if (question.skill != PracticeSkill.drawing) return;
    if (_modelStatus != HandwritingModelStatus.ready) {
      throw StateError(
        'Download the Japanese handwriting model to check drawings.',
      );
    }
    final candidates = await _handwriting.recognize(
      strokes: ink.strokes
          .map(
            (stroke) => stroke.points
                .map(
                  (point) => (
                    x: point.x,
                    y: point.y,
                    milliseconds: point.milliseconds,
                  ),
                )
                .toList(),
          )
          .toList(),
      width: ink.width,
      height: ink.height,
    );
    final outcome = Grader.drawing(_itemFor(question), candidates);
    if (outcome == ReviewOutcome.neutral) {
      _feedback = AnswerFeedback(
        outcome: outcome,
        response: candidates.isEmpty ? '' : candidates.first,
        message:
            'Recognition was uncertain. Please redraw; this does not affect your progress.',
      );
      return;
    }
    await _record(question, outcome, candidates.first);
  });

  @override
  Future<void> revealAnswer() => _run(() async {
    if (!_canAnswer) return;
    await _record(
      _activeSession!.currentQuestion!,
      ReviewOutcome.revealed,
      'Answer revealed',
    );
  });

  Future<void> _record(
    LessonQuestion question,
    ReviewOutcome outcome,
    String response,
  ) async {
    final attempt = ReviewAttempt(
      questionId: question.id,
      itemId: question.itemId,
      skill: question.skill,
      outcome: outcome,
      answeredAt: _now(),
      response: response,
      assisted: outcome == ReviewOutcome.revealed,
    );
    final key = SkillProgress.keyFor(question.itemId, question.skill);
    final updated = ReviewScheduler.apply(_progress[key], attempt);
    final nextProgress = {..._progress, key: updated};
    final unlocked = KanjiUnlock.update(
      _kanjiUnlocked,
      _curriculum,
      nextProgress,
    );
    final session = _activeSession!.withAttempt(attempt, advance: false);
    final feedback = AnswerFeedback(outcome: outcome, response: response);
    final saved = await _repository!.saveAnswer(
      attempt: attempt,
      progress: updated,
      kanjiUnlocked: unlocked,
      checkpoint: _checkpoint(session: session, feedback: feedback),
    );
    if (!saved) {
      await _reload();
      return;
    }
    _progress = nextProgress;
    _kanjiUnlocked = unlocked;
    _activeSession = session;
    _feedback = feedback;
  }

  @override
  Future<void> advance() => _run(() async {
    if (_activeSession == null ||
        _feedback == null ||
        _feedback!.outcome == ReviewOutcome.neutral) {
      return;
    }
    final session = _activeSession!.copyWith(
      currentIndex: _activeSession!.currentIndex + 1,
    );
    await _repository!.saveCheckpoint(LessonCheckpoint(session: session));
    _activeSession = session;
    _feedback = null;
  });

  @override
  Future<void> exitLesson() => _run(() async {
    // Every completed answer is already committed. Keep unfinished lessons for Resume.
    if (_activeSession?.isComplete ?? false) {
      await _repository!.saveCheckpoint(null);
      _activeSession = null;
      _introIds = [];
      _feedback = null;
    }
  });

  @override
  Future<void> abandonLesson() => _run(() async {
    await _repository!.saveCheckpoint(null);
    _activeSession = null;
    _introIds = [];
    _feedback = null;
  });

  @override
  Future<void> downloadModel() async {
    if (_loading ||
        _modelStatus == HandwritingModelStatus.downloading ||
        _modelStatus == HandwritingModelStatus.ready) {
      return;
    }
    _error = null;
    _modelStatus = HandwritingModelStatus.downloading;
    _notify();
    try {
      // Model preparation must not hold the lesson/storage operation lock.
      await _handwriting.download().timeout(const Duration(minutes: 3));
      _modelStatus = HandwritingModelStatus.ready;
    } catch (_) {
      _modelStatus = HandwritingModelStatus.failed;
      _error =
          'Could not download the handwriting model. Check your connection and retry. Keyboard lessons remain available.';
    } finally {
      _notify();
    }
  }

  @override
  Future<String> exportBackup() async {
    if (_repository == null) {
      throw StateError('Your progress is still loading.');
    }
    return _repository!.exportBackup(now: _now());
  }

  @override
  Future<void> importBackup(String json) async {
    if (_busy || _loading) {
      throw StateError('Wait until the current operation finishes.');
    }
    _busy = true;
    _notify();
    try {
      await _repository!.restoreBackup(
        json,
        _curriculum.map((item) => item.id).toSet(),
      );
      await _reload();
      _error = null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void clearError() {
    _error = null;
    _notify();
  }

  @override
  void retryAnswer() {
    if (_feedback?.outcome != ReviewOutcome.neutral || _busy) return;
    _feedback = null;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> close() async {
    await _repository?.close();
    await _handwriting.close();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
