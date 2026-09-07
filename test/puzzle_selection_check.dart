import '../lib/data/models/puzzle_model.dart';
import '../lib/data/models/puzzle_selection.dart';

PuzzleQuestion q(int id, {String? text}) => PuzzleQuestion(
  id: '$id',
  puzzleType: 'Multiple Choice Question',
  category: 'museum',
  questionText: text ?? 'What is exhibit $id?',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  optionD: 'D',
  correctAnswer: 'A',
);

PuzzleQuestion scrambled(int id, String answer) => PuzzleQuestion(
  id: 'scrambled-$id',
  puzzleType: 'Guess the Word',
  category: 'museum',
  questionText: 'Scrambled clue $id?',
  optionA: '',
  optionB: '',
  optionC: '',
  optionD: '',
  correctAnswer: answer,
);
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final old = List.generate(10, q);
  final recent = old.map((q) => q.id).toSet();
  check(
    selectPuzzleRound(old, recent, recent).length == 2,
    'Must not replay all ten',
  );
  final pool = [...old, ...List.generate(8, (i) => q(i + 10))];
  for (var i = 0; i < 50; i++) {
    final round = selectPuzzleRound(pool, recent, recent);
    check(round.length == 10, 'Eight fresh plus two repeats');
    check(
      round.where((q) => recent.contains(q.id)).length <= 2,
      'Repeat limit',
    );
  }
  final dedup = uniquePuzzleQuestions([
    q(1, text: 'What is this?'),
    q(2, text: ' WHAT is this ! '),
  ]);
  check(dedup.length == 1, 'Punctuation/case variants must deduplicate');
  final fresh = selectPuzzleRound([...pool, q(18), q(19)], recent, recent);
  check(fresh.every((q) => !recent.contains(q.id)), 'Prefer all ten fresh');
  final scrambledRound = selectPuzzleRound(
    [
      scrambled(1, 'Cendol'),
      scrambled(2, 'CENDOL'),
      ...List.generate(10, (i) => scrambled(i + 3, 'Answer $i')),
    ],
    {},
    {},
  );
  check(
    scrambledRound
            .where((q) => puzzleTextKey(q.correctAnswer) == 'cendol')
            .length ==
        1,
    'A scrambled answer must appear only once in a round',
  );
  print(
    'Passed: unique rounds, fresh priority, and maximum two recent repeats.',
  );
}
