import '../../data/models/puzzle_model.dart';
import '../../data/repositories/puzzle_repository.dart';

class PuzzleChallengeService {
  final PuzzleRepository _repository;

  PuzzleChallengeService({PuzzleRepository? repository})
    : _repository = repository ?? PuzzleRepository();

  // ============================================================
  // PUZZLE RULES
  // ============================================================

  static const int questionsPerChallenge = 10;
  static const int maxMarksPerQuestion = 10;
  static const int questionTimeLimitSeconds = 30;

  static const int maximumHintsPerQuestion = 3;

  static const int firstHintPenalty = 3;
  static const int secondHintPenalty = 3;

  static const int dailyRewardedChallengeLimit = 5;

  // ============================================================
  // LOAD QUESTIONS
  // ============================================================

  Future<List<PuzzleQuestion>> loadChallengeQuestions({
    required String userId,
    String? destinationId,
    required String puzzleType,
  }) async {
    return _repository.getRandomQuestions(
      userId: userId,
      destinationId: destinationId,
      puzzleType: puzzleType,
      questionCount: questionsPerChallenge,
    );
  }

  Future<List<PuzzleChallengeHistory>> loadPuzzleHistory({
    required String userId,
  }) {
    return _repository.getPuzzleHistory(userId: userId);
  }

  // ============================================================
  // VALIDATE CHALLENGE
  // ============================================================

  bool isChallengeReady(List<PuzzleQuestion> questions) {
    return questions.length == questionsPerChallenge;
  }

  // ============================================================
  // CHECK ANSWER
  // ============================================================

  bool checkAnswer({
    required String userAnswer,
    required String correctAnswer,
  }) {
    return userAnswer.trim().toLowerCase() ==
        correctAnswer.trim().toLowerCase();
  }

  // ============================================================
  // CALCULATE TIME SCORE
  // ============================================================

  int calculateTimeScore({
    required int remainingTimeSeconds,
    int maximumMarks = maxMarksPerQuestion,
    int timeLimitSeconds = questionTimeLimitSeconds,
  }) {
    if (remainingTimeSeconds <= 0) {
      return 0;
    }

    if (remainingTimeSeconds >= timeLimitSeconds) {
      return maximumMarks;
    }

    final double ratio = remainingTimeSeconds / timeLimitSeconds;

    final int score = (ratio * maximumMarks).floor();

    return score.clamp(0, maximumMarks);
  }

  // ============================================================
  // CALCULATE QUESTION SCORE
  // ============================================================

  int calculateQuestionScore({
    required bool isCorrect,
    required int remainingTimeSeconds,
    required int hintsUsed,
  }) {
    // Incorrect answer = 0 marks.
    if (!isCorrect) {
      return 0;
    }

    // Third hint reveals the answer.
    // Therefore this question receives 0 marks.
    if (hintsUsed >= 3) {
      return 0;
    }

    int score = calculateTimeScore(remainingTimeSeconds: remainingTimeSeconds);

    // Hint 1 = -3.
    if (hintsUsed >= 1) {
      score -= firstHintPenalty;
    }

    // Hint 2 = another -3.
    if (hintsUsed >= 2) {
      score -= secondHintPenalty;
    }

    return score.clamp(0, maxMarksPerQuestion);
  }

  // ============================================================
  // HINT
  // ============================================================

  HintResult useHint({
    required PuzzleQuestion question,
    required int hintsUsed,
  }) {
    if (hintsUsed >= maximumHintsPerQuestion) {
      return const HintResult(
        hintNumber: 3,
        text: null,
        penalty: 0,
        answerRevealed: true,
      );
    }

    switch (hintsUsed) {
      case 0:
        return HintResult(
          hintNumber: 1,
          text: question.hint1,
          penalty: firstHintPenalty,
          answerRevealed: false,
        );

      case 1:
        return HintResult(
          hintNumber: 2,
          text: question.hint2,
          penalty: secondHintPenalty,
          answerRevealed: false,
        );

      case 2:
        return HintResult(
          hintNumber: 3,
          text: question.hint3,
          penalty: 0,
          answerRevealed: true,
          revealedAnswer: question.correctAnswer,
        );

      default:
        return const HintResult(
          hintNumber: 3,
          text: null,
          penalty: 0,
          answerRevealed: true,
        );
    }
  }

  bool canUseHint(int hintsUsed) {
    return hintsUsed < maximumHintsPerQuestion;
  }

  // ============================================================
  // TOTAL SCORE
  // ============================================================

  int calculateTotalScore(List<int> questionScores) {
    return questionScores.fold(0, (total, score) => total + score);
  }

  // ============================================================
  // TOTAL HINTS
  // ============================================================

  int calculateTotalHints(List<int> hintsUsed) {
    return hintsUsed.fold(0, (total, hints) => total + hints);
  }

  // ============================================================
  // TOTAL COMPLETION TIME
  // ============================================================

  int calculateCompletionTime(List<int> questionTimes) {
    return questionTimes.fold(0, (total, time) => total + time);
  }

  // ============================================================
  // DAILY REWARD ELIGIBILITY
  // ============================================================

  Future<bool> canEarnReward({required String userId}) async {
    final completedToday = await _repository.countRewardedChallengesToday(
      userId: userId,
    );

    return completedToday < dailyRewardedChallengeLimit;
  }

  Future<int> getRemainingRewardedChallenges({required String userId}) async {
    final completedToday = await _repository.countRewardedChallengesToday(
      userId: userId,
    );

    final remaining = dailyRewardedChallengeLimit - completedToday;

    return remaining.clamp(0, dailyRewardedChallengeLimit);
  }

  // ============================================================
  // START ATTEMPT
  // ============================================================

  Future<String> startAttempt({
    required String userId,
    required String puzzleType,
  }) async {
    return _repository.createPuzzleAttempt(
      userId: userId,
      puzzleType: puzzleType,
    );
  }

  // ============================================================
  // SAVE QUESTION ANSWER
  // ============================================================

  Future<void> saveQuestionAnswer({
    required String attemptId,
    required PuzzleQuestion question,
    required String submittedAnswer,
    required bool isCorrect,
    required int marksObtained,
    required int remainingTimeSeconds,
    required int hintsUsed,
  }) async {
    await _repository.savePuzzleAnswer(
      attemptId: attemptId,
      puzzleId: question.id,
      submittedAnswer: submittedAnswer,
      isCorrect: isCorrect,
      marksObtained: marksObtained,
      remainingTimeSeconds: remainingTimeSeconds,
      hintsUsed: hintsUsed,
    );
  }

  // ============================================================
  // COMPLETE ATTEMPT
  // ============================================================

  Future<PuzzleCompletionResult> completeAttempt({
    required String attemptId,
    required int completionTimeSeconds,
    required int rewardPoints,
  }) async {
    return _repository.completePuzzleAttempt(
      attemptId: attemptId,
      completionTimeSeconds: completionTimeSeconds,
      rewardPoints: rewardPoints,
    );
  }
}

// ============================================================
// HINT RESULT
// ============================================================

class HintResult {
  final int hintNumber;
  final String? text;
  final int penalty;
  final bool answerRevealed;
  final String? revealedAnswer;

  const HintResult({
    required this.hintNumber,
    required this.text,
    required this.penalty,
    required this.answerRevealed,
    this.revealedAnswer,
  });
}
