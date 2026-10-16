import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/domain.dart';

class LessonCheckpoint {
  const LessonCheckpoint({
    required this.session,
    this.introIds = const [],
    this.feedback,
  });
  final LessonSession session;
  final List<String> introIds;
  final Map<String, dynamic>? feedback;

  Map<String, dynamic> toJson() => {
    'session': session.toJson(),
    'introIds': introIds,
    'feedback': feedback,
  };

  factory LessonCheckpoint.fromJson(Map<String, dynamic> json) =>
      LessonCheckpoint(
        session: LessonSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map),
        ),
        introIds: List<String>.from(json['introIds'] as List? ?? []),
        feedback: json['feedback'] == null
            ? null
            : Map<String, dynamic>.from(json['feedback'] as Map),
      );
}

class StoredProgress {
  const StoredProgress({
    required this.progress,
    required this.kanjiUnlocked,
    this.checkpoint,
  });
  final Map<String, SkillProgress> progress;
  final bool kanjiUnlocked;
  final LessonCheckpoint? checkpoint;
}

class ValidatedBackup {
  const ValidatedBackup(
    this.progress,
    this.attempts,
    this.kanjiUnlocked,
    this.checkpoint,
  );
  final List<SkillProgress> progress;
  final List<ReviewAttempt> attempts;
  final bool kanjiUnlocked;
  final LessonCheckpoint? checkpoint;
}

/// Validate the complete portable backup before opening a replacement transaction.
class BackupCodec {
  static ValidatedBackup validate(String source, Set<String> itemIds) {
    if (source.length > 20 * 1024 * 1024) {
      throw const FormatException('This backup is too large (maximum 20 MB).');
    }
    try {
      final root = jsonDecode(source);
      if (root is! Map<String, dynamic> ||
          root['format'] != 'kana-path' ||
          root['version'] != 1 ||
          root['curriculumVersion'] != 1 ||
          root['kanjiUnlocked'] is! bool ||
          root['progress'] is! List ||
          root['attempts'] is! List) {
        throw const FormatException('Choose a Kana Path version 1 backup.');
      }
      final progress = <SkillProgress>[];
      final keys = <String>{};
      for (final entry in root['progress'] as List) {
        final map = Map<String, dynamic>.from(entry as Map);
        for (final key in [
          'successfulReviews',
          'correctCount',
          'incorrectCount',
        ]) {
          if (map[key] is! int || (map[key] as int) < 0) {
            throw const FormatException('Invalid progress counts.');
          }
        }
        final value = SkillProgress.fromJson(map);
        if (!itemIds.contains(value.itemId) ||
            !keys.add(value.key) ||
            value.successfulReviews > value.correctCount ||
            (value.lastAdvancedDate != null &&
                !RegExp(
                  r'^\d{4}-\d{2}-\d{2}$',
                ).hasMatch(value.lastAdvancedDate!))) {
          throw const FormatException(
            'The backup contains invalid or duplicate progress.',
          );
        }
        progress.add(value);
      }
      final attempts = <ReviewAttempt>[];
      final attemptIds = <String>{};
      final canonicalAttempts = <String, ReviewAttempt>{};
      for (final entry in root['attempts'] as List) {
        final value = ReviewAttempt.fromJson(
          Map<String, dynamic>.from(entry as Map),
        );
        if (!itemIds.contains(value.itemId) ||
            value.questionId.isEmpty ||
            !attemptIds.add(value.questionId) ||
            value.outcome == ReviewOutcome.neutral) {
          throw const FormatException(
            'The backup contains invalid or duplicate answers.',
          );
        }
        attempts.add(value);
        canonicalAttempts[value.questionId] = value;
      }
      LessonCheckpoint? checkpoint;
      if (root['checkpoint'] != null) {
        checkpoint = LessonCheckpoint.fromJson(
          Map<String, dynamic>.from(root['checkpoint'] as Map),
        );
        final session = checkpoint.session;
        final questions = session.questions;
        if (questions.isEmpty ||
            questions.length > 100 ||
            session.currentIndex < 0 ||
            session.currentIndex > questions.length ||
            questions.any((q) => !itemIds.contains(q.itemId) || q.id.isEmpty) ||
            questions.map((q) => q.id).toSet().length != questions.length ||
            checkpoint.introIds.any((id) => !itemIds.contains(id))) {
          throw const FormatException('The saved lesson is invalid.');
        }
        final questionMap = {
          for (final question in questions) question.id: question,
        };
        final sessionIds = <String>{};
        for (final attempt in session.attempts) {
          final question = questionMap[attempt.questionId];
          if (question == null ||
              question.itemId != attempt.itemId ||
              question.skill != attempt.skill ||
              !attemptIds.contains(attempt.questionId) ||
              !sessionIds.add(attempt.questionId) ||
              jsonEncode(attempt.toJson()) !=
                  jsonEncode(canonicalAttempts[attempt.questionId]!.toJson())) {
            throw const FormatException(
              'The saved lesson contains invalid answers.',
            );
          }
        }
        final feedback = checkpoint.feedback;
        if (session.attempts.length !=
            session.currentIndex + (feedback == null ? 0 : 1)) {
          throw const FormatException(
            'The saved lesson position does not match its answers.',
          );
        }
        for (var index = 0; index < session.attempts.length; index++) {
          if (session.attempts[index].questionId != questions[index].id) {
            throw const FormatException(
              'The saved lesson answers are out of order.',
            );
          }
        }
        if (feedback != null) {
          final outcome = ReviewOutcome.values.byName(
            feedback['outcome'] as String,
          );
          if (outcome == ReviewOutcome.neutral ||
              feedback['response'] is! String ||
              session.currentQuestion == null ||
              !sessionIds.contains(session.currentQuestion!.id) ||
              canonicalAttempts[session.currentQuestion!.id]!.outcome !=
                  outcome ||
              canonicalAttempts[session.currentQuestion!.id]!.response !=
                  feedback['response']) {
            throw const FormatException('The saved feedback is invalid.');
          }
        }
      }
      return ValidatedBackup(
        progress,
        attempts,
        root['kanjiUnlocked'] as bool,
        checkpoint,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This file is not a valid Kana Path backup.');
    }
  }
}

class ProgressRepository {
  ProgressRepository._(this._db);
  final Database _db;

  static Future<ProgressRepository> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final actualFactory = factory ?? databaseFactory;
    final location =
        databasePath ??
        path.join(await actualFactory.getDatabasesPath(), 'kana_path.db');
    final db = await actualFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE progress (id TEXT PRIMARY KEY, json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE attempts (id TEXT PRIMARY KEY, json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE metadata (id TEXT PRIMARY KEY, json TEXT NOT NULL)',
          );
        },
      ),
    );
    return ProgressRepository._(db);
  }

  Future<StoredProgress> load() async {
    final rows = await _db.query('progress');
    final meta = {
      for (final row in await _db.query('metadata'))
        row['id'] as String: row['json'] as String,
    };
    return StoredProgress(
      progress: {
        for (final row in rows)
          row['id'] as String: SkillProgress.fromJson(
            jsonDecode(row['json'] as String) as Map<String, dynamic>,
          ),
      },
      kanjiUnlocked: meta['kanjiUnlocked'] == 'true',
      checkpoint: meta['checkpoint'] == null
          ? null
          : LessonCheckpoint.fromJson(
              jsonDecode(meta['checkpoint']!) as Map<String, dynamic>,
            ),
    );
  }

  Future<void> saveCheckpoint(LessonCheckpoint? checkpoint) =>
      _db.transaction((txn) => _checkpoint(txn, checkpoint));

  Future<void> saveUnlock(bool unlocked) =>
      _meta(_db, 'kanjiUnlocked', jsonEncode(unlocked));

  /// Idempotent question IDs prevent lifecycle retries from counting twice.
  Future<bool> saveAnswer({
    required ReviewAttempt attempt,
    required SkillProgress progress,
    required bool kanjiUnlocked,
    required LessonCheckpoint checkpoint,
  }) => _db.transaction((txn) async {
    if ((await txn.query(
      'attempts',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [attempt.questionId],
    )).isNotEmpty) {
      return false;
    }
    await txn.insert('attempts', {
      'id': attempt.questionId,
      'json': jsonEncode(attempt.toJson()),
    });
    await txn.insert('progress', {
      'id': progress.key,
      'json': jsonEncode(progress.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _meta(txn, 'kanjiUnlocked', jsonEncode(kanjiUnlocked));
    await _checkpoint(txn, checkpoint);
    return true;
  });

  Future<String> exportBackup({DateTime? now}) => _db.transaction((txn) async {
    final progress = await txn.query('progress', orderBy: 'id');
    final attempts = await txn.query('attempts', orderBy: 'id');
    final metadata = {
      for (final row in await txn.query('metadata'))
        row['id'] as String: row['json'] as String,
    };
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'kana-path',
      'version': 1,
      'curriculumVersion': 1,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'kanjiUnlocked': metadata['kanjiUnlocked'] == 'true',
      'progress': progress
          .map((row) => jsonDecode(row['json'] as String))
          .toList(),
      'attempts': attempts
          .map((row) => jsonDecode(row['json'] as String))
          .toList(),
      'checkpoint': metadata['checkpoint'] == null
          ? null
          : jsonDecode(metadata['checkpoint']!),
    });
  });

  Future<void> restoreBackup(String source, Set<String> itemIds) async {
    final backup = BackupCodec.validate(source, itemIds);
    await _db.transaction((txn) async {
      await txn.delete('progress');
      await txn.delete('attempts');
      await txn.delete('metadata');
      for (final progress in backup.progress) {
        await txn.insert('progress', {
          'id': progress.key,
          'json': jsonEncode(progress.toJson()),
        });
      }
      for (final attempt in backup.attempts) {
        await txn.insert('attempts', {
          'id': attempt.questionId,
          'json': jsonEncode(attempt.toJson()),
        });
      }
      await _meta(txn, 'kanjiUnlocked', jsonEncode(backup.kanjiUnlocked));
      await _checkpoint(txn, backup.checkpoint);
    });
  }

  static Future<void> _meta(
    DatabaseExecutor db,
    String key,
    String value,
  ) async {
    await db.insert('metadata', {
      'id': key,
      'json': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _checkpoint(
    DatabaseExecutor db,
    LessonCheckpoint? checkpoint,
  ) async {
    if (checkpoint == null) {
      await db.delete('metadata', where: 'id = ?', whereArgs: ['checkpoint']);
    } else {
      await _meta(db, 'checkpoint', jsonEncode(checkpoint.toJson()));
    }
  }

  Future<void> close() => _db.close();
}
