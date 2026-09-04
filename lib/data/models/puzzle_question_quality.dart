/// Legacy place-identification templates are not destination trivia.
bool isDestinationTriviaText(String text) => !RegExp(
  r'mystery clue|location detail|destination profile|explorer check|google maps?|google listing|\baddress\b|\bpostcode\b|\bcoordinates\b|^(?:question\s*\d+|which (?:place|destination|location)\b)',
  caseSensitive: false,
).hasMatch(text.trim());

class PuzzlePreparationException implements Exception {
  final String message;
  const PuzzlePreparationException(this.message);
}
