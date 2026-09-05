import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/puzzle_model.dart';
import '../models/puzzle_question_quality.dart';
import '../models/puzzle_selection.dart';

class PuzzleRepository {
  final SupabaseClient _supabase;

  PuzzleRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================
  // GET QUESTIONS
  // ============================================================

  Future<List<PuzzleQuestion>> getQuestions({
    String? destinationId,
    required String puzzleType,
    bool allowPreparation = true,
  }) async {
    final response = destinationId == null
        ? await _supabase
              .from('puzzle_questions')
              .select()
              .isFilter('destination_id', null)
              .eq('category', 'Malaysia General Knowledge')
              .eq('puzzle_type', puzzleType)
              .eq('is_active', true)
        : await _supabase
              .from('puzzle_questions')
              .select()
              .eq('destination_id', destinationId)
              .eq('puzzle_type', puzzleType)
              .eq('is_active', true);

    final questions = (response as List)
        .map((json) => PuzzleQuestion.fromMap(Map<String, dynamic>.from(json)))
        .toList();
    final usable = questions
        .where((question) => isDestinationTriviaText(question.questionText))
        .toList();
    // Repair legacy banks from Puzzle Challenge, not by consuming a new draw.
    if (destinationId != null && usable.length < 10 && allowPreparation) {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return usable;
      final draws = await _supabase
          .from('blind_box_history')
          .select('history_id')
          .eq('user_id', userId)
          .eq('destination_id', destinationId)
          .limit(1);
      // Do not invoke Blind Box preparation for a teammate's checkpoint.
      if (draws.isEmpty) return usable;
      try {
        final result = await _supabase.functions.invoke(
          'generate-destination-questions',
          body: {'destination_id': destinationId, 'puzzle_type': puzzleType},
        );
        if (result.status < 200 || result.status >= 300) {
          throw const PuzzlePreparationException(
            'Destination questions are not ready. Your draw is saved; retry here without drawing again.',
          );
        }
      } on FunctionException catch (error) {
        final details = error.details;
        throw PuzzlePreparationException(
          details is Map && details['error'] is String
              ? details['error'] as String
              : 'Question preparation failed. Your draw is saved; retry here without drawing again.',
        );
      }
      return getQuestions(
        destinationId: destinationId,
        puzzleType: puzzleType,
        allowPreparation: false,
      );
    }
    return uniquePuzzleQuestions(usable);
  }

  // ============================================================
  // GET RANDOM QUESTIONS
  // ============================================================

  Future<List<PuzzleQuestion>> getRandomQuestions({
    required String userId,
    String? destinationId,
    required String puzzleType,
    String? historyCategory,
    int questionCount = 10,
  }) async {
    var questions = await getQuestions(
      destinationId: destinationId,
      puzzleType: puzzleType,
      allowPreparation: false,
    );

    // Read every completed round, not just the API's default first page.
    final previousAttempts = await _readPages((from, to) => _supabase
        .from('puzzle_attempts')
        .select('attempt_id, completed_at')
        .eq('user_id', userId)
        .eq('puzzle_category', historyCategory ?? puzzleType)
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false)
        .order('attempt_id')
        .range(from, to));

    final attemptIds = (previousAttempts as List)
        .map((row) => row['attempt_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final answeredPuzzleIds = <String>{};
    final recentlyAnsweredPuzzleIds = <String>{};
    if (attemptIds.isNotEmpty) {
      final previousAnswers = <Map<String, dynamic>>[];
      // Keep URLs bounded and paginate answers so long-term players do not
      // have old questions incorrectly classified as unseen.
      for (var start = 0; start < attemptIds.length; start += 50) {
        final ids = attemptIds.skip(start).take(50).toList();
        previousAnswers.addAll(await _readPages((from, to) => _supabase
            .from('puzzle_attempt_answers')
            .select(
              'puzzle_id, attempt_id, '
              'puzzle_questions(question_text, destination_id)',
            )
            .inFilter('attempt_id', ids)
            .order('attempt_id').order('puzzle_id')
            .range(from, to)));
      }

      // General questions are shared across destinations; avoid the latest
      // round's IDs even when it was at a different destination.
      recentlyAnsweredPuzzleIds.addAll((previousAnswers as List)
          .where((row) => row['attempt_id']?.toString() == attemptIds.first)
          .map((row) => row['puzzle_id'].toString()));

      answeredPuzzleIds.addAll(
        (previousAnswers as List)
            .map((row) => row['puzzle_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );

      final poolIds = questions.map((q) => q.id).toSet();
      final poolTextKeys = questions
          .map((q) => puzzleTextKey(q.questionText))
          .toSet();
      String answerKey(dynamic row) => row['puzzle_questions'] is Map
          ? puzzleTextKey(
              row['puzzle_questions']['question_text']?.toString() ?? '',
            )
          : '';
      String? answerDestinationId(dynamic row) =>
          row['puzzle_questions'] is Map
          ? row['puzzle_questions']['destination_id']?.toString()
          : null;
      // Question wording can legitimately be similar at different places.
      // Only history explicitly linked to this exact destination may mark its
      // local rows seen. General rows are shared by their stable puzzle IDs;
      // a missing relation must never suppress a destination question.
      bool belongsToCurrentPool(dynamic row) {
        final rowDestinationId = answerDestinationId(row);
        return rowDestinationId != null && rowDestinationId == destinationId;
      }

      final relevantPreviousAnswers = (previousAnswers as List)
          .where(belongsToCurrentPool)
          .toList();
      final answeredKeys = relevantPreviousAnswers.map(answerKey).toSet();
      answeredPuzzleIds.addAll(
        questions
            .where((q) => answeredKeys.contains(puzzleTextKey(q.questionText)))
            .map((q) => q.id),
      );
      final relevantAttempts = relevantPreviousAnswers
          .where(
            (row) =>
                poolIds.contains(row['puzzle_id']?.toString()) ||
                poolTextKeys.contains(answerKey(row)),
          )
          .map((row) => row['attempt_id']?.toString())
          .toSet();
      final latestAttemptId = attemptIds
          .where(relevantAttempts.contains)
          .firstOrNull;
      final recentKeys = relevantPreviousAnswers
          .where((row) => row['attempt_id']?.toString() == latestAttemptId)
          .map(answerKey)
          .toSet();
      recentlyAnsweredPuzzleIds.addAll(
        questions
            .where((q) => recentKeys.contains(puzzleTextKey(q.questionText)))
            .map((q) => q.id),
      );
      recentlyAnsweredPuzzleIds.addAll(
        relevantPreviousAnswers
            .where((row) => row['attempt_id']?.toString() == latestAttemptId)
            .map((row) => row['puzzle_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );
    }

    // Every playable text category follows one selection contract: saved
    // destination questions first, then same-category Malaysia General rows.
    // This also applies automatically when a new category bank is added.
    const destinationFirstTypes = {
      'Multiple Choice Question',
      'Guess the Word',
      'Scrambled Word',
      'Missing Word Challenge',
      'True or False',
    };
    if (destinationId != null && destinationFirstTypes.contains(puzzleType)) {
      final general = questions.where((q) => !answeredPuzzleIds.contains(q.id) &&
                  !recentlyAnsweredPuzzleIds.contains(q.id)).length >= questionCount
          ? <PuzzleQuestion>[]
          : (await _supabase.from('puzzle_questions').select()
              .isFilter('destination_id', null)
              .eq('category', 'Malaysia General Knowledge')
              .eq('puzzle_type', puzzleType).eq('is_active', true) as List)
              .map((row) => PuzzleQuestion.fromMap(Map<String, dynamic>.from(row)))
              .toList();
      final round = selectDestinationFirstRound(questions, general,
          answeredPuzzleIds, recentlyAnsweredPuzzleIds, count: questionCount);
      if (round.length != questionCount) {
        throw const PuzzlePreparationException('The saved question library is incomplete. Please contact support. Your draw is saved.');
      }
      return round;
    }

    String? preparationFailure;
    if (selectPuzzleRound(questions, answeredPuzzleIds,
            recentlyAnsweredPuzzleIds, count: questionCount).length < questionCount) {
      try {
        final preparation = await _supabase.functions.invoke(
          'generate-destination-questions',
          body: {
            if (destinationId != null) 'destination_id': destinationId,
            'random_mode': destinationId == null,
            'puzzle_type': puzzleType,
            'exclude_question_ids': {
              ...recentlyAnsweredPuzzleIds,
              ...answeredPuzzleIds,
            }.take(1000).toList(),
          },
        );
        // Another user or the draw's background worker may already be filling
        // this bank. Read saved results rather than launching duplicate work.
        if (preparation.status == 202) {
          for (var poll = 0; poll < 40; poll++) {
            await Future<void>.delayed(const Duration(seconds: 3));
            questions = await getQuestions(destinationId: destinationId,
                puzzleType: puzzleType, allowPreparation: false);
            if (selectPuzzleRound(questions, answeredPuzzleIds,
                    recentlyAnsweredPuzzleIds, count: questionCount).length >= questionCount) {
              break;
            }
          }
        }
      } on FunctionException catch (error) {
        final details = error.details;
        preparationFailure = details is Map && details['error'] is String
            ? details['error'] as String
            : 'Question generation could not reach the server. Please check your connection.';
      } catch (_) {
        preparationFailure = 'Question generation could not reach the server. Please check your connection.';
        // Keep usable saved questions when the provider is unavailable.
        // The selection rule below still prevents a ten-out-of-ten repeat.
      }
      questions = await getQuestions(
        destinationId: destinationId,
        puzzleType: puzzleType,
        allowPreparation: false,
      );
    }
    final selection = selectPuzzleRound(
      questions,
      answeredPuzzleIds,
      recentlyAnsweredPuzzleIds,
      count: questionCount,
    );
    if (selection.length < questionCount) {
      throw PuzzlePreparationException(
        preparationFailure ?? 'We are still preparing enough different questions for this challenge. '
        'Your progress is saved. Please try again shortly or choose another puzzle category.',
      );
    }
    selection.shuffle();
    // Replenishment is independent of this ready round: never hold a playable
    // database selection hostage to the model's availability.
    if (destinationId != null) {
      unawaited(_growSharedBank(destinationId));
    }
    return selection;
  }

  Future<List<Map<String, dynamic>>> _readPages(
    Future<List<Map<String, dynamic>>> Function(int from, int to) fetch,
  ) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var from = 0; ; from += pageSize) {
      final page = await fetch(from, from + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<void> _growSharedBank(String destinationId) async {
    try {
      await _supabase.functions.invoke('generate-destination-questions',
          body: {'destination_id': destinationId, 'prepare_all': true});
    } catch (_) {
      // Saved rounds still work. A later draw/play can resume replenishment.
    }
  }

  Future<List<PuzzleChallengeHistory>> getPuzzleHistory({
    required String userId,
  }) async {
    final attempts = await _supabase
        .from('puzzle_attempts')
        .select(
          'attempt_id, puzzle_category, total_score, points_earned, '
          'total_hints_used, completion_time_seconds, completed_at',
        )
        .eq('user_id', userId)
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false);

    final attemptRows = List<Map<String, dynamic>>.from(attempts as List);
    final attemptIds = attemptRows
        .map((row) => row['attempt_id']?.toString())
        .whereType<String>()
        .toList();
    if (attemptIds.isEmpty) return const [];

    final answers = await _supabase
        .from('puzzle_attempt_answers')
        .select(
          'attempt_id, submitted_answer, is_correct, marks_obtained, '
          'remaining_time_seconds, hints_used, answered_at, '
          'question_text_snapshot, correct_answer_snapshot, '
          'question_category_snapshot, timer_seconds_snapshot, '
          'puzzle_questions(question_text, correct_answer, timer_seconds, category, '
          'blind_box_destinations(name))',
        )
        .inFilter('attempt_id', attemptIds)
        .order('answered_at');

    final answersByAttempt = <String, List<PuzzleAnswerHistory>>{};
    final destinationsByAttempt = <String, Set<String>>{};
    for (final raw in answers as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final question = row['puzzle_questions'] is Map
          ? Map<String, dynamic>.from(row['puzzle_questions'] as Map)
          : <String, dynamic>{};
      final destination = question['blind_box_destinations'];
      final destinationName = destination is Map
          ? destination['name']?.toString().trim()
          : null;
      if (destinationName != null && destinationName.isNotEmpty) {
        destinationsByAttempt
            .putIfAbsent(row['attempt_id'].toString(), () => <String>{})
            .add(destinationName);
      } else if (question['category'] == 'Malaysia General Knowledge') {
        destinationsByAttempt
            .putIfAbsent(row['attempt_id'].toString(), () => <String>{})
            .add('Malaysia General Knowledge');
      }
      final snapshotQuestion = row['question_text_snapshot']?.toString().trim();
      final snapshotAnswer = row['correct_answer_snapshot']?.toString().trim();
      final limit = _parseInt(
        row['timer_seconds_snapshot'] ?? question['timer_seconds'],
        30,
      );
      final remaining = _parseInt(row['remaining_time_seconds'], 0);
      final answer = PuzzleAnswerHistory(
        questionText: snapshotQuestion != null && snapshotQuestion.isNotEmpty
            ? snapshotQuestion
            : question['question_text']?.toString() ?? 'Question',
        submittedAnswer: row['submitted_answer']?.toString() ?? '',
        correctAnswer: snapshotAnswer != null && snapshotAnswer.isNotEmpty
            ? snapshotAnswer
            : question['correct_answer']?.toString() ?? '',
        isCorrect: row['is_correct'] == true,
        marksObtained: _parseInt(row['marks_obtained'], 0),
        timeTakenSeconds: (limit - remaining).clamp(0, limit),
        hintsUsed: _parseInt(row['hints_used'], 0),
      );
      answersByAttempt
          .putIfAbsent(row['attempt_id'].toString(), () => [])
          .add(answer);
    }

    return attemptRows.map((row) {
      final id = row['attempt_id'].toString();
      return PuzzleChallengeHistory(
        destinationNames: destinationsByAttempt[id]?.toList() ?? const [],
        attemptId: id,
        puzzleCategory: row['puzzle_category']?.toString() ?? 'Puzzle',
        totalScore: _parseInt(row['total_score'], 0),
        pointsEarned: _parseInt(row['points_earned'], 0),
        totalHintsUsed: _parseInt(row['total_hints_used'], 0),
        completionTimeSeconds: _parseInt(row['completion_time_seconds'], 0),
        completedAt: DateTime.tryParse(row['completed_at']?.toString() ?? ''),
        answers: answersByAttempt[id] ?? const [],
      );
    }).toList();
  }

  int _parseInt(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  // ============================================================
  // COUNT TODAY'S REWARDED CHALLENGES
  // ============================================================

  Future<int> countRewardedChallengesToday({required String userId}) async {
    final malaysiaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final startOfDayUtc = DateTime.utc(
      malaysiaNow.year,
      malaysiaNow.month,
      malaysiaNow.day,
    ).subtract(const Duration(hours: 8));
    final startOfNextDayUtc = startOfDayUtc.add(const Duration(days: 1));

    final response = await _supabase
        .from('puzzle_attempts')
        .select('attempt_id')
        .eq('user_id', userId)
        .eq('reward_eligible', true)
        .gte('completed_at', startOfDayUtc.toIso8601String())
        .lt('completed_at', startOfNextDayUtc.toIso8601String());

    return (response as List).length;
  }

  // ============================================================
  // CREATE PUZZLE ATTEMPT
  // ============================================================

  Future<String> createPuzzleAttempt({
    required String userId,
    required String puzzleType,
  }) async {
    final response = await _supabase
        .from('puzzle_attempts')
        .insert({
          'user_id': userId,
          'puzzle_category': puzzleType,
          'total_score': 0,
          'points_earned': 0,
          'total_hints_used': 0,
          'completion_time_seconds': 0,
          'reward_eligible': false,
          'completed_at': null,
        })
        .select('attempt_id')
        .single();

    return response['attempt_id'].toString();
  }

  // ============================================================
  // SAVE INDIVIDUAL QUESTION ANSWER
  // ============================================================

  Future<void> savePuzzleAnswer({
    required String attemptId,
    required String puzzleId,
    required String questionText,
    required String correctAnswer,
    required String questionCategory,
    required int timerSeconds,
    required String submittedAnswer,
    required bool isCorrect,
    required int marksObtained,
    required int remainingTimeSeconds,
    required int hintsUsed,
  }) async {
    await _supabase.from('puzzle_attempt_answers').insert({
      'attempt_id': attemptId,
      'puzzle_id': puzzleId,
      'question_text_snapshot': questionText,
      'correct_answer_snapshot': correctAnswer,
      'question_category_snapshot': questionCategory,
      'timer_seconds_snapshot': timerSeconds,
      'submitted_answer': submittedAnswer,
      'is_correct': isCorrect,
      'marks_obtained': marksObtained,
      'remaining_time_seconds': remainingTimeSeconds,
      'hints_used': hintsUsed,
    });
  }

  // ============================================================
  // COMPLETE PUZZLE ATTEMPT
  // ============================================================

  Future<PuzzleCompletionResult> completePuzzleAttempt({
    required String attemptId,
    required int completionTimeSeconds,
    required int rewardPoints,
  }) async {
    final response = await _supabase.rpc(
      'complete_puzzle_attempt',
      params: {
        'p_attempt_id': attemptId,
        'p_completion_time_seconds': completionTimeSeconds,
        'p_reward_points': rewardPoints,
      },
    );

    final rows = response as List;
    if (rows.isEmpty) {
      throw StateError('Puzzle completion did not return a result.');
    }

    return PuzzleCompletionResult.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}

class PuzzleCompletionResult {
  final int totalScore;
  final int pointsEarned;
  final bool rewardEligible;
  final int rewardedChallengesToday;
  final int dailyScore;
  final int? leaderboardRank;

  const PuzzleCompletionResult({
    required this.totalScore,
    required this.pointsEarned,
    required this.rewardEligible,
    required this.rewardedChallengesToday,
    required this.dailyScore,
    required this.leaderboardRank,
  });

  factory PuzzleCompletionResult.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;

    final rankValue = map['leaderboard_rank'];
    return PuzzleCompletionResult(
      totalScore: parseInt(map['total_score']),
      pointsEarned: parseInt(map['points_earned']),
      rewardEligible: map['reward_eligible'] == true,
      rewardedChallengesToday: parseInt(map['rewarded_challenges_today']),
      dailyScore: parseInt(map['daily_score']),
      leaderboardRank: rankValue == null ? null : parseInt(rankValue),
    );
  }
}
