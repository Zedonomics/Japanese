import 'package:flutter/foundation.dart';

import '../domain/domain.dart';

enum HandwritingModelStatus { unavailable, downloading, ready, failed }

class AnswerFeedback {
  const AnswerFeedback({
    required this.outcome,
    required this.response,
    this.message,
  });

  final ReviewOutcome outcome;
  final String response;
  final String? message;
}

class InkPoint {
  const InkPoint(this.x, this.y, this.milliseconds);

  final double x;
  final double y;
  final int milliseconds;
}

class InkStroke {
  const InkStroke(this.points);

  final List<InkPoint> points;
}

class InkSubmission {
  const InkSubmission({
    required this.strokes,
    required this.width,
    required this.height,
  });

  final List<InkStroke> strokes;
  final double width;
  final double height;
}

/// Presentation boundary. All grading, scheduling, and persistence live outside
/// widgets; the controller notifies after every visible state change.
abstract class LearningController extends ChangeNotifier {
  List<LearningItem> get curriculum;
  Map<String, SkillProgress> get progress;
  LessonSession? get activeSession;
  List<LearningItem> get introItems;
  AnswerFeedback? get feedback;
  bool get loading;
  bool get busy;
  String? get error;
  bool get kanjiUnlocked;
  HandwritingModelStatus get modelStatus;

  Future<void> startLesson(LessonScope scope, LessonFocus focus);
  void completeIntroduction();
  Future<void> submitText(String answer);
  Future<void> submitDrawing(InkSubmission ink);
  Future<void> revealAnswer();
  void retryAnswer();
  Future<void> advance();
  Future<void> exitLesson();
  Future<void> abandonLesson();
  Future<void> downloadModel();
  Future<String> exportBackup();
  Future<void> importBackup(String json);
  void clearError();
}
