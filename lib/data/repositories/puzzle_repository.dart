import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/puzzle_model.dart';
import '../models/puzzle_question_quality.dart';

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
    return usable;
  }

  // ============================================================
  // GET RANDOM QUESTIONS
  // ============================================================

  Future<List<PuzzleQuestion>> getRandomQuestions({
    required String userId,
    String? destinationId,
    required String puzzleType,
    int questionCount = 10,
  }) async {
    final questions = await getQuestions(
      destinationId: destinationId,
      puzzleType: puzzleType,
    );

    if (questions.length <= questionCount) {
      questions.shuffle();
      return questions;
    }

    final previousAttempts = await _supabase
        .from('puzzle_attempts')
        .select('attempt_id, completed_at')
        .eq('user_id', userId)
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false);

    final attemptIds = (previousAttempts as List)
        .map((row) => row['attempt_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final answeredPuzzleIds = <String>{};
    final recentlyAnsweredPuzzleIds = <String>{};
    if (attemptIds.isNotEmpty) {
      final previousAnswers = await _supabase
          .from('puzzle_attempt_answers')
          .select('puzzle_id, attempt_id')
          .inFilter('attempt_id', attemptIds);

      answeredPuzzleIds.addAll(
        (previousAnswers as List)
            .map((row) => row['puzzle_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );

      final latestAttemptId = attemptIds.first;
      recentlyAnsweredPuzzleIds.addAll(
        (previousAnswers as List)
            .where((row) => row['attempt_id']?.toString() == latestAttemptId)
            .map((row) => row['puzzle_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );
    }

    // Prefer questions the player has not answered before. Once every
    // question has been seen, reset the pool naturally by using all of them.
    final unusedQuestions = questions
        .where((question) => !answeredPuzzleIds.contains(question.id))
        .toList();

    final selection = <PuzzleQuestion>[...unusedQuestions];
    if (selection.length < questionCount) {
      final previouslySeenQuestions = questions
          .where(
            (question) =>
                answeredPuzzleIds.contains(question.id) &&
                !recentlyAnsweredPuzzleIds.contains(question.id),
          )
          .toList();
      previouslySeenQuestions.shuffle();
      selection.addAll(
        previouslySeenQuestions.take(questionCount - selection.length),
      );

      if (selection.length < questionCount) {
        final recentQuestions = questions
            .where(
              (question) => recentlyAnsweredPuzzleIds.contains(question.id),
            )
            .toList();
        recentQuestions.shuffle();
        selection.addAll(
          recentQuestions.take(questionCount - selection.length),
        );
      }
    }

    selection.shuffle();

    return selection.take(questionCount).toList();
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
          'puzzle_questions(question_text, correct_answer, timer_seconds, '
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
      }
      final limit = _parseInt(question['timer_seconds'], 30);
      final remaining = _parseInt(row['remaining_time_seconds'], 0);
      final answer = PuzzleAnswerHistory(
        questionText: question['question_text']?.toString() ?? 'Question',
        submittedAnswer: row['submitted_answer']?.toString() ?? '',
        correctAnswer: question['correct_answer']?.toString() ?? '',
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
    required String submittedAnswer,
    required bool isCorrect,
    required int marksObtained,
    required int remainingTimeSeconds,
    required int hintsUsed,
  }) async {
    await _supabase.from('puzzle_attempt_answers').insert({
      'attempt_id': attemptId,
      'puzzle_id': puzzleId,
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
