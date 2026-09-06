/// Legacy place-identification templates are not destination trivia.
bool isDestinationTriviaText(String text) => !RegExp(
  r'mystery clue|location detail|destination profile|explorer check|google maps?|google listing|\baddress\b|\bpostcode\b|\bcoordinates\b|^(?:question\s*\d+|which (?:place|destination|location)\b)',
  caseSensitive: false,
).hasMatch(text.trim());

final RegExp _legacyTrueFalsePattern = RegExp(
  r'^“(.+)” correctly answers: “(.+)”$',
  dotAll: true,
);

/// Rejects malformed database rows before they can be shown to a traveller.
bool isPlayableCategoryQuestion({
  required String puzzleType,
  required String questionText,
  required String correctAnswer,
  required List<String> options,
  String? displayBoxContent,
}) {
  final question = questionText.trim();
  final answer = correctAnswer.trim();
  if (question.isEmpty ||
      answer.isEmpty ||
      !isDestinationTriviaText(question)) {
    return false;
  }

  final normalizedOptions = options.map((value) => value.trim()).toList();
  if (puzzleType == 'True or False') {
    final optionKeys = normalizedOptions
        .map((value) => value.toLowerCase())
        .toSet();
    final answerKey = answer.toLowerCase();
    final proposedAnswer = displayBoxContent?.trim() ?? '';
    final hasUsefulBox =
        proposedAnswer.isNotEmpty &&
        proposedAnswer.toLowerCase() != 'true' &&
        proposedAnswer.toLowerCase() != 'false';
    return optionKeys.length == 2 &&
        optionKeys.containsAll(const {'true', 'false'}) &&
        (answerKey == 'true' || answerKey == 'false') &&
        (hasUsefulBox || _legacyTrueFalsePattern.hasMatch(question));
  }

  if (puzzleType == 'Multiple Choice Question' ||
      puzzleType == 'Missing Word Challenge') {
    return question.endsWith('?') &&
        normalizedOptions.length == 4 &&
        normalizedOptions.every((value) => value.isNotEmpty) &&
        normalizedOptions.map((value) => value.toLowerCase()).toSet().length ==
            4 &&
        normalizedOptions.any(
          (value) => value.toLowerCase() == answer.toLowerCase(),
        );
  }

  return true;
}

/// Hints are derived from the exact stored answer, so stale database hints can
/// never contradict the question's marked answer.
String reliablePuzzleHint({
  required String puzzleType,
  required String correctAnswer,
  required int hintNumber,
}) {
  final answer = correctAnswer.trim();
  if (puzzleType == 'True or False') {
    if (hintNumber == 1) {
      return 'Check whether the proposed answer directly and factually answers the question.';
    }
    if (hintNumber == 2) {
      return 'The correct choice starts with “${answer.isEmpty ? '?' : answer[0].toUpperCase()}”.';
    }
    return 'The correct choice is $answer.';
  }

  final words = answer
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (hintNumber == 1) {
    return 'The answer contains ${words.length} ${words.length == 1 ? 'word' : 'words'}.';
  }
  if (hintNumber == 2) {
    final initials = words.map((word) => word[0].toUpperCase()).join(' · ');
    return 'The answer begins with $initials.';
  }
  return 'The correct answer is $answer.';
}

class PuzzlePreparationException implements Exception {
  final String message;
  const PuzzlePreparationException(this.message);
}
