import 'puzzle_model.dart';

String puzzleTextKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'unscramble:.*$', caseSensitive: false), '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Use unseen destination content first. A replay must not force the same
/// destination bank again: unseen general content fills the shortage. Once
/// both banks are exhausted, recycle older questions before recent ones.
List<PuzzleQuestion> selectDestinationFirstRound(
  List<PuzzleQuestion> destination,
  List<PuzzleQuestion> general,
  Set<String> answered,
  Set<String> recent, {
  int count = 10,
}) {
  if (count <= 0) return [];
  final local = uniquePuzzleQuestions(destination);
  final national = uniquePuzzleQuestions(
    general.where((q) => q.isMalaysiaGeneral),
  );
  final seenKeys = [...local, ...national]
      .where((q) => answered.contains(q.id) || recent.contains(q.id))
      .map((q) => puzzleTextKey(q.questionText))
      .toSet();
  final recentKeys = [...local, ...national]
      .where((q) => recent.contains(q.id))
      .map((q) => puzzleTextKey(q.questionText))
      .toSet();
  bool fresh(PuzzleQuestion q) =>
      !seenKeys.contains(puzzleTextKey(q.questionText));
  bool older(PuzzleQuestion q) =>
      !fresh(q) && !recentKeys.contains(puzzleTextKey(q.questionText));
  List<PuzzleQuestion> shuffled(Iterable<PuzzleQuestion> pool) =>
      pool.toList()..shuffle();
  final selected = <PuzzleQuestion>[];
  final keys = <String>{};
  void add(Iterable<PuzzleQuestion> pool, {int? limit}) {
    var added = 0;
    for (final q in pool) {
      if (selected.length >= count || (limit != null && added >= limit)) break;
      if (keys.add(puzzleTextKey(q.questionText))) {
        selected.add(q);
        added++;
      }
    }
  }

  add(shuffled(local.where(fresh)));
  add(shuffled(national.where(fresh)));
  add(shuffled(local.where(older)));
  add(shuffled(national.where(older)));
  add(
    shuffled(
      [
        ...local,
        ...national,
      ].where((q) => recentKeys.contains(puzzleTextKey(q.questionText))),
    ),
    limit: 2,
  );
  return selected..shuffle();
}

String? malaysiaFallbackNotice(List<PuzzleQuestion> questions) {
  final general = questions.where((q) => q.isMalaysiaGeneral).length;
  if (general == 0) return null;
  final local = questions.length - general;
  return local == 0
      ? 'No new destination questions are available for this round, so it '
            'contains $general general Malaysia questions.'
      : 'This destination currently provides $local questions for this round. '
            'The remaining $general are general Malaysia questions.';
}

List<PuzzleQuestion> uniquePuzzleQuestions(Iterable<PuzzleQuestion> questions) {
  final keys = <String>{};
  return questions
      .where((q) => keys.add(puzzleTextKey(q.questionText)))
      .toList();
}

/// Never silently serve the entire previous round again. At most two repeats
/// from the latest round for this destination/category are permitted.
List<PuzzleQuestion> selectPuzzleRound(
  List<PuzzleQuestion> questions,
  Set<String> answered,
  Set<String> recent, {
  int count = 10,
}) {
  final unique = uniquePuzzleQuestions(questions);
  final fresh = unique.where((q) => !answered.contains(q.id)).toList()
    ..shuffle();
  final older =
      unique
          .where((q) => answered.contains(q.id) && !recent.contains(q.id))
          .toList()
        ..shuffle();
  final repeats = unique.where((q) => recent.contains(q.id)).toList()
    ..shuffle();
  return [...fresh, ...older, ...repeats.take(2)].take(count).toList();
}
