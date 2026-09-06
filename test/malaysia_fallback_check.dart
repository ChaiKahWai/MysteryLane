import '../lib/data/models/puzzle_model.dart';
import '../lib/data/models/puzzle_selection.dart';

PuzzleQuestion q(int n, {bool general = false, String? text}) => PuzzleQuestion(
  id: '${general ? 'g' : 'd'}$n',
  destinationId: general ? null : 'destination',
  puzzleType: 'Multiple Choice Question',
  category: general ? 'Malaysia General Knowledge' : 'History',
  questionText: text ?? '${general ? 'Malaysia' : 'Destination'} question $n?',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  optionD: 'D',
  correctAnswer: 'A',
);
void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void main() {
  final general = List.generate(100, (i) => q(i, general: true));
  final generalWordRiddle = PuzzleQuestion(
    id: 'word-general',
    destinationId: null,
    puzzleType: 'Guess the Word',
    category: 'Malaysia General Knowledge',
    questionText: 'Which Malaysian city is the national capital?',
    optionA: '',
    optionB: '',
    optionC: '',
    optionD: '',
    correctAnswer: 'KUALALUMPUR',
  );
  check(
    generalWordRiddle.isMalaysiaGeneral,
    'General fallback supports Word Riddle questions',
  );
  for (var size = 0; size <= 15; size++) {
    final local = List.generate(size, q);
    final round = selectDestinationFirstRound(local, general, {}, {});
    check(round.length == 10, 'Always ten');
    check(
      round.where((q) => !q.isMalaysiaGeneral).length ==
          (size < 10 ? size : 10),
      'Strict destination priority',
    );
    check(uniquePuzzleQuestions(round).length == 10, 'No duplicates');
    check(
      (malaysiaFallbackNotice(round) == null) == (size >= 10),
      'Notice only for fallback',
    );
  }
  final round = selectDestinationFirstRound(
    List.generate(6, q),
    general,
    {'g0', 'g1'},
    {'g0', 'g1'},
  );
  check(
    !round.any((q) => q.id == 'g0' || q.id == 'g1'),
    'Prefer unseen general questions',
  );
  final repeated = List.generate(10, q);
  final replay = selectDestinationFirstRound(
    repeated,
    general,
    repeated.map((q) => q.id).toSet(),
    repeated.map((q) => q.id).toSet(),
  );
  check(
    replay.length == 10 && replay.every((q) => q.isMalaysiaGeneral),
    'Ten-question bank: second round uses fresh general content',
  );
  check(
    malaysiaFallbackNotice(replay)!.contains('already been played'),
    'Replay notice explains limited fresh content',
  );
  final fifteen = List.generate(15, q);
  final mixed = selectDestinationFirstRound(
    fifteen,
    general,
    repeated.map((q) => q.id).toSet(),
    repeated.map((q) => q.id).toSet(),
  );
  check(
    mixed.where((q) => !q.isMalaysiaGeneral).length == 5,
    'Use all five unseen destination questions',
  );
  check(
    mixed.every((q) => !repeated.map((q) => q.id).contains(q.id)),
    'No previous-round repeats when fresh fillers exist',
  );
  // Aquaria-sized bank: seven complete rounds of unseen local questions,
  // then seven remaining local questions plus three fresh general questions.
  final large = List.generate(77, q);
  final seen = <String>{};
  var recent = <String>{};
  for (var turn = 0; turn < 20; turn++) {
    final next = selectDestinationFirstRound(large, general, seen, recent);
    check(next.length == 10, 'Full round even after both banks are exhausted');
    check(uniquePuzzleQuestions(next).length == 10, 'Round uniqueness');
    check(
      next.every((q) => !recent.contains(q.id)),
      'Avoid the previous round while older alternatives exist',
    );
    if (turn < 7)
      check(
        next.every((q) => !q.isMalaysiaGeneral && !seen.contains(q.id)),
        'Large bank supplies fresh destination rounds',
      );
    if (turn == 7)
      check(
        next.where((q) => !q.isMalaysiaGeneral).length == 7,
        'Preserve last seven unseen local questions',
      );
    recent = next.map((q) => q.id).toSet();
    seen.addAll(recent);
  }
  check(
    selectDestinationFirstRound(
      repeated,
      general,
      {},
      repeated.map((q) => q.id).toSet(),
    ).every((q) => q.isMalaysiaGeneral),
    'Recent-only IDs must not count as fresh',
  );
  check(
    selectDestinationFirstRound(repeated, general, {}, {}, count: 0).isEmpty,
    'Zero requested',
  );
  final duplicate = selectDestinationFirstRound(
    [q(0, text: general.first.questionText)],
    general,
    {},
    {},
  );
  check(
    uniquePuzzleQuestions(duplicate).length == 10,
    'Cross-bank duplicates excluded',
  );
  print(
    'Passed: first rounds, 10/15/77-question replay banks, exhaustion, notices and cross-bank deduplication.',
  );
}
