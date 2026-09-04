class PuzzleQuestion {
  final String id;
  final String? destinationId;
  final String puzzleType;
  final String category;
  final String questionText;

  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;

  final String correctAnswer;

  final String? hint1;
  final String? hint2;
  final String? hint3;

  final String? difficultyLevel;
  final int markAllocation;
  final int timerSeconds;

  final String? imageUrl;
  final bool isActive;

  const PuzzleQuestion({
    required this.id,
    this.destinationId,
    required this.puzzleType,
    required this.category,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    this.hint1,
    this.hint2,
    this.hint3,
    this.difficultyLevel,
    this.markAllocation = 10,
    this.timerSeconds = 30,
    this.imageUrl,
    this.isActive = true,
  });

  List<String> get options => [
    optionA,
    optionB,
    optionC,
    optionD,
  ].where((option) => option.trim().isNotEmpty).toList();

  factory PuzzleQuestion.fromMap(Map<String, dynamic> map) {
    return PuzzleQuestion(
      id: map['puzzle_id'].toString(),
      destinationId: map['destination_id']?.toString(),
      puzzleType: map['puzzle_type']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      questionText: map['question_text']?.toString() ?? '',
      optionA: map['option_a']?.toString() ?? '',
      optionB: map['option_b']?.toString() ?? '',
      optionC: map['option_c']?.toString() ?? '',
      optionD: map['option_d']?.toString() ?? '',
      correctAnswer: map['correct_answer']?.toString() ?? '',
      hint1: map['hint_1']?.toString(),
      hint2: map['hint_2']?.toString(),
      hint3: map['hint_3']?.toString(),
      difficultyLevel: map['difficulty_level']?.toString(),
      markAllocation: _parseInt(map['mark_allocation'], 10),
      timerSeconds: _parseInt(map['timer_seconds'], 30),
      imageUrl: map['image_url']?.toString(),
      isActive: map['is_active'] ?? true,
    );
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }
}

class PuzzleChallengeHistory {
  final List<String> destinationNames;
  String get destinationLabel => destinationNames.isEmpty
      ? 'Destination unavailable'
      : destinationNames.join(', ');
  final String attemptId;
  final String puzzleCategory;
  final int totalScore;
  final int pointsEarned;
  final int totalHintsUsed;
  final int completionTimeSeconds;
  final DateTime? completedAt;
  final List<PuzzleAnswerHistory> answers;

  const PuzzleChallengeHistory({
    this.destinationNames = const [],
    required this.attemptId,
    required this.puzzleCategory,
    required this.totalScore,
    required this.pointsEarned,
    required this.totalHintsUsed,
    required this.completionTimeSeconds,
    required this.completedAt,
    required this.answers,
  });
}

class PuzzleAnswerHistory {
  final String questionText;
  final String submittedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int marksObtained;
  final int timeTakenSeconds;
  final int hintsUsed;

  const PuzzleAnswerHistory({
    required this.questionText,
    required this.submittedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.marksObtained,
    required this.timeTakenSeconds,
    required this.hintsUsed,
  });
}
