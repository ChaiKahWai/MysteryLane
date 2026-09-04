import '../lib/data/models/puzzle_question_quality.dart';

void main() {
  final rejected = [
    'Destination profile 23: Which place is described as follows: Merdeka 118?',
    'Mystery clue 5: Which destination matches this Google location address?',
    'Location detail 18: Which address belongs to Merdeka 118?',
    'Explorer check 4: Which destination belongs to this category?',
    'Which destination has 118 floors?',
  ];
  final accepted = [
    'How many floors does Merdeka 118 have?',
    'What does the word Merdeka mean?',
    'What inspired the design of Merdeka 118?',
  ];
  for (final text in rejected) {
    if (isDestinationTriviaText(text)) throw StateError('Accepted legacy text: $text');
  }
  for (final text in accepted) {
    if (!isDestinationTriviaText(text)) throw StateError('Rejected trivia: $text');
  }
  print('Passed ${rejected.length + accepted.length} question-quality checks.');
}
