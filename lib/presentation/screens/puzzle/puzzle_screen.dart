import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_imports.dart';

import '../../../data/datasources/supabase_datasource.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../home/home_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../../../application/services/puzzle_challenge_service.dart';
import '../../../data/models/puzzle_model.dart';
import '../../../data/models/puzzle_question_quality.dart';
import '../../../data/models/puzzle_selection.dart';

// ============================================================
// ENUMS & EXTENSIONS
// ============================================================

enum PuzzleCategory { image, scrambled, word, mcq, trueFalse }

const List<PuzzleCategory> playablePuzzleCategories = [
  PuzzleCategory.scrambled,
  PuzzleCategory.word,
  PuzzleCategory.mcq,
  PuzzleCategory.trueFalse,
];

extension PuzzleCategoryX on PuzzleCategory {
  String get key {
    switch (this) {
      case PuzzleCategory.image:
        return 'Image Guessing';
      case PuzzleCategory.scrambled:
        return 'Guess the Word';
      case PuzzleCategory.word:
        return 'Missing Word Challenge';
      case PuzzleCategory.mcq:
        return 'Multiple Choice Question';
      case PuzzleCategory.trueFalse:
        return 'True or False';
    }
  }

  String get historyKey {
    switch (this) {
      case PuzzleCategory.scrambled:
        return 'Scrambled Anagrams';
      default:
        return key;
    }
  }
}

enum PuzzleLocationSource { blindBox, checkpoint }

extension PuzzleLocationSourceX on PuzzleLocationSource {
  String get filterLabel {
    switch (this) {
      case PuzzleLocationSource.blindBox:
        return 'Blind Box';
      case PuzzleLocationSource.checkpoint:
        return 'Checkpoint';
    }
  }

  String get cardLabel {
    switch (this) {
      case PuzzleLocationSource.blindBox:
        return 'Location from Blind Box';
      case PuzzleLocationSource.checkpoint:
        return 'Location from Checkpoint';
    }
  }
}

class MissionCheckpoint {
  final String? id;
  final String title;
  final String? imageUrl;
  final String? locationName;
  final String? city;
  final String category;
  final int epReward;

  const MissionCheckpoint({
    this.id,
    required this.title,
    this.imageUrl,
    this.locationName,
    this.city,
    this.category = 'Puzzle',
    this.epReward = 500,
  });
}

class CategoryQuestion {
  final String id;
  final PuzzleCategory category;
  final String question;
  final String subtitle;
  final String answer;
  final String hint;
  final List<String>? options;
  final String? imageUrl;
  final String? locationId;
  final String? displayBoxContent;

  const CategoryQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.subtitle,
    required this.answer,
    required this.hint,
    this.options,
    this.imageUrl,
    this.locationId,
    this.displayBoxContent,
  });
}

class CategoryInfo {
  final String title;
  final String description;
  final String icon;
  final String difficulty;

  const CategoryInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.difficulty,
  });
}

const Map<PuzzleCategory, CategoryInfo> categoryInfo = {
  PuzzleCategory.image: CategoryInfo(
    title: 'Image Recognition',
    description:
    'Identify ancient landmarks, secret artifacts, or hidden clues from field photos.',
    icon: '📸',
    difficulty: 'Medium',
  ),
  PuzzleCategory.scrambled: CategoryInfo(
    title: 'Scrambled Anagrams',
    description:
    'Unscramble mixed letters to unlock destination names & passcode words.',
    icon: '🔤',
    difficulty: 'Easy',
  ),
  PuzzleCategory.word: CategoryInfo(
    title: 'Missing Word Challenge',
    description:
    'Answer destination questions by choosing the correct word or phrase.',
    icon: '🧩',
    difficulty: 'Easy',
  ),
  PuzzleCategory.mcq: CategoryInfo(
    title: 'Multiple Choice Trivia',
    description:
    'Select the correct historical answer from 4 location choices.',
    icon: '❓',
    difficulty: 'Easy',
  ),
  PuzzleCategory.trueFalse: CategoryInfo(
    title: 'True or False',
    description:
    'Verify statement accuracy regarding mystery travel lore and facts.',
    icon: '☑️',
    difficulty: 'Quick',
  ),
};

const List<CategoryQuestion> puzzleQuestionDatabase = [
  CategoryQuestion(
    id: 'q-word-1',
    category: PuzzleCategory.word,
    question: 'Which mountain is called "the roof of the Alps"?',
    subtitle: 'Missing Word Challenge · Choose the correct answer.',
    answer: 'Mont Blanc',
    hint:
    'Located in the western Alps on the French-Italian border.',
    options: ['Mont Blanc', 'Mount Fuji', 'Mount Kinabalu', 'Ben Nevis'],
  ),
  CategoryQuestion(
    id: 'q-word-2',
    category: PuzzleCategory.word,
    question: 'What is the capital city of Japan?',
    subtitle: 'Missing Word Challenge · Choose the correct answer.',
    answer: 'Tokyo',
    hint: 'This megacity was formerly known as Edo.',
    options: ['Tokyo', 'Kyoto', 'Osaka', 'Nagoya'],
  ),
  CategoryQuestion(
    id: 'q-image-1',
    category: PuzzleCategory.image,
    question: 'Identify the ancient shrine gate shown in Kyoto field records:',
    subtitle: 'Image Recognition · Inspect landmark details.',
    answer: 'Fushimi Inari',
    hint:
    'Famous for its thousands of vibrant vermilion torii gates winding up Mount Inari.',
    imageUrl:
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=800&q=80',
  ),
  CategoryQuestion(
    id: 'q-image-2',
    category: PuzzleCategory.image,
    question: 'Name this iconic Paris landmark in the photo:',
    subtitle: 'Image Recognition · Inspect landmark details.',
    answer: 'Eiffel Tower',
    hint: 'Built for the 1889 World\'s Fair.',
    imageUrl:
    'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f?auto=format&fit=crop&w=800&q=80',
  ),
  CategoryQuestion(
    id: 'q-scrambled-1',
    category: PuzzleCategory.scrambled,
    question: 'Unscramble the ancient Japanese imperial capital: "OTYOK"',
    subtitle: 'Word Anagram · Reorder the letters.',
    answer: 'KYOTO',
    hint:
    'Former capital of Japan, renowned for classical Buddhist temples, gardens, and wooden houses.',
  ),
  CategoryQuestion(
    id: 'q-scrambled-2',
    category: PuzzleCategory.scrambled,
    question: 'Unscramble this world-famous city: "SIPAR"',
    subtitle: 'Word Anagram · Reorder the letters.',
    answer: 'PARIS',
    hint: 'Known as the City of Light.',
  ),
  CategoryQuestion(
    id: 'q-mcq-1',
    category: PuzzleCategory.mcq,
    question: 'Which sacred river flows through the historic center of Kyoto?',
    subtitle: 'Multiple Choice · Choose the correct answer.',
    answer: 'Kamo River',
    hint:
    'Its riverbanks are a popular walking spot for locals and visitors in Kyoto.',
    options: ['Kamo River', 'Sumida River', 'Yodo River', 'Shinano River'],
  ),
  CategoryQuestion(
    id: 'q-mcq-2',
    category: PuzzleCategory.mcq,
    question: 'Which country is home to the Great Barrier Reef?',
    subtitle: 'Multiple Choice · Choose the correct answer.',
    answer: 'Australia',
    hint: 'This country is also a continent.',
    options: ['Australia', 'Indonesia', 'Philippines', 'New Zealand'],
  ),
  CategoryQuestion(
    id: 'q-tf-1',
    category: PuzzleCategory.trueFalse,
    question:
    'Kyoto was originally chosen as the site for the Japanese imperial court in 794 AD.',
    subtitle: 'True or False · Verify the statement.',
    answer: 'True',
    hint:
    'Heian-kyo (Kyoto) served as Japan\'s imperial capital from 794 until 1868.',
    options: ['True', 'False'],
  ),
  CategoryQuestion(
    id: 'q-tf-2',
    category: PuzzleCategory.trueFalse,
    question:
    'The Great Wall of China is visible from the Moon with the naked eye.',
    subtitle: 'True or False · Verify the statement.',
    answer: 'False',
    hint: 'This is a common myth debunked by astronauts.',
    options: ['True', 'False'],
  ),
];

final Map<PuzzleCategory, CategoryQuestion> categoryQuestions = {
  for (final question in puzzleQuestionDatabase) question.category: question,
};

// ============================================================
// PUZZLE SCREEN
// ============================================================

class PuzzleScreen extends StatefulWidget {
  final MissionCheckpoint? mission;
  final PuzzleLocationSource initialLocationSource;
  final int userEp;
  final ValueChanged<int>? onSolveSuccess;

  const PuzzleScreen({
    super.key,
    this.mission,
    this.initialLocationSource = PuzzleLocationSource.checkpoint,
    this.userEp = 0,
    this.onSolveSuccess,
  });

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
static const Color skyBlue = Color(0xFF0284C7);
static const Color pageBackground = Color(0xFFF8FAFC);

String viewMode = 'categories';
String hubTab = 'selection';

PuzzleCategory selectedCategory = PuzzleCategory.word;

final PuzzleChallengeService _challengeService = PuzzleChallengeService();

// Real Supabase puzzle challenge state
List<PuzzleQuestion> _challengeQuestions = [];
int _challengeQuestionIndex = 0;
String? _attemptId;

bool _isLoadingChallenge = false;
String? _preparationNotice;
bool _isSubmittingAnswer = false;

int _challengeCompletionTimeSeconds = 0;
int _earnedEpForChallenge = 0;
int _dailyPuzzleScore = 0;
int? _dailyLeaderboardRank;
int _rewardedChallengesToday = 0;
bool _challengeWasRewardEligible = true;

bool _lastAnswerWasCorrect = false;
bool _lastAnswerTimedOut = false;
int _lastEarnedMarks = 0;

int questionIndex = 1;
int score = 0;
int timerSeconds = 30;
int elapsedSeconds = 0;

String answerInput = '';
String? selectedOption;

int hintsAvailable = 3;
int hintsUsedCount = 0;

bool showHintModal = false;
String? errorMsg;
bool isSolved = false;

Timer? questionTimer;
Timer? countdownTimer;
final ScrollController _questionScrollController = ScrollController();

int countdownSeconds = 23 * 3600 + 42 * 60 + 15;
late int _userEp;
late PuzzleLocationSource _locationSource;
bool _isLoadingBlindBoxLocations = false;
final List<MissionCheckpoint> _blindBoxLocations = [];
final List<MissionCheckpoint> _savedCheckpointLocations = [];
int _selectedBlindBoxIndex = 0;
int? _selectedSavedCheckpointIndex;
final SupabaseDataSource _supabaseDataSource = SupabaseDataSource();
final Random _random = Random();
CategoryQuestion? _currentResolvedQuestion;
List<PuzzleChallengeHistory> _puzzleHistory = [];
bool _isLoadingHistory = true;
String? _historyError;
PuzzleCategory? _historyCategoryFilter;
String? _headerProfilePictureUrl;

// ---------- Getters ----------
CategoryQuestion get currentQuestion {
if (_challengeQuestions.isNotEmpty &&
_challengeQuestionIndex < _challengeQuestions.length) {
return _convertPuzzleQuestionToCategoryQuestion(
_challengeQuestions[_challengeQuestionIndex],
);
}

return _currentResolvedQuestion ??
_resolveQuestionForCategory(selectedCategory);
}

bool get _hasBlindBoxLocations => _blindBoxLocations.isNotEmpty;

bool get _hasCheckpointLocation => _activeCheckpointMission != null;

bool get _hasCurrentCheckpoint =>
widget.mission != null && widget.mission!.title.trim().isNotEmpty;

MissionCheckpoint? get _activeCheckpointMission {
final savedIndex = _selectedSavedCheckpointIndex;
if (savedIndex != null &&
savedIndex >= 0 &&
savedIndex < _savedCheckpointLocations.length) {
return _savedCheckpointLocations[savedIndex];
}
return _hasCurrentCheckpoint ? widget.mission : null;
}

bool get _isRandomPuzzleMode => _activeLocationMission == null;

bool get _showBlindBoxFilterContent =>
_locationSource == PuzzleLocationSource.blindBox && _hasBlindBoxLocations;

bool get _showCheckpointFilterContent =>
_locationSource == PuzzleLocationSource.checkpoint &&
_hasCheckpointLocation;

MissionCheckpoint? get _checkpointMission => _activeCheckpointMission;

MissionCheckpoint? get _activeLocationMission {
if (_locationSource == PuzzleLocationSource.blindBox) {
if (_blindBoxLocations.isEmpty) return null;
final safeIndex = _selectedBlindBoxIndex.clamp(
0,
_blindBoxLocations.length - 1,
);
return _blindBoxLocations[safeIndex];
}

return _checkpointMission;
}

int get epReward {
if (_isRandomPuzzleMode ||
_locationSource == PuzzleLocationSource.blindBox) {
return 200;
}
final mission = _activeLocationMission;
if (mission == null) return 200;
return mission.epReward > 0 ? mission.epReward : 200;
}

// ---------- Lifecycle ----------
@override
void initState() {
super.initState();
_userEp = widget.userEp;
_locationSource = widget.initialLocationSource;
_loadBlindBoxLocations();
_loadSavedCheckpointLocations();
_loadPuzzleHistory();
_loadHeaderProfile();

countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
if (!mounted) return;
setState(() {
countdownSeconds = countdownSeconds > 0
? countdownSeconds - 1
: 24 * 3600;
});
});
}

@override
void dispose() {
questionTimer?.cancel();
countdownTimer?.cancel();
_questionScrollController.dispose();
super.dispose();
}

// ---------- Helper methods ----------
List<CategoryQuestion> _questionsForCategory(PuzzleCategory category) {
return puzzleQuestionDatabase
.where((question) => question.category == category)
.toList();
}

CategoryQuestion _personalizeForLocation(
CategoryQuestion base,
MissionCheckpoint location,
) {
final locationLabel = location.locationName ?? location.title;

return CategoryQuestion(
id: '${base.id}-${location.id ?? location.title}',
category: base.category,
question: 'Regarding ${location.title}: ${base.question}',
subtitle: '${base.subtitle} · Field target: $locationLabel',
answer: base.answer,
hint: '${base.hint} Think about ${location.title}.',
options: base.options,
imageUrl: location.imageUrl ?? base.imageUrl,
locationId: location.id,
);
}

CategoryQuestion _resolveQuestionForCategory(PuzzleCategory category) {
final pool = _questionsForCategory(category);
if (pool.isEmpty) {
return categoryQuestions[category]!;
}

if (_isRandomPuzzleMode) {
return pool[_random.nextInt(pool.length)];
}

final location = _activeLocationMission;
if (location == null) {
return pool[_random.nextInt(pool.length)];
}

if (location.id != null) {
final locationSpecific = pool
.where((question) => question.locationId == location.id)
.toList();
if (locationSpecific.isNotEmpty) {
return locationSpecific.first;
}
}

final genericPool = pool
.where((question) => question.locationId == null)
.toList();
final base = genericPool.isNotEmpty
? genericPool[_random.nextInt(genericPool.length)]
: pool.first;

return _personalizeForLocation(base, location);
}

void _syncLocationFilterAfterLoad() {
if (_hasBlindBoxLocations && !_hasCurrentCheckpoint) {
_locationSource = PuzzleLocationSource.blindBox;
_selectedBlindBoxIndex = 0;
return;
}

if (_hasCurrentCheckpoint && !_hasBlindBoxLocations) {
_locationSource = PuzzleLocationSource.checkpoint;
return;
}

if (_hasBlindBoxLocations && _hasCurrentCheckpoint) {
if (widget.initialLocationSource == PuzzleLocationSource.checkpoint) {
_locationSource = PuzzleLocationSource.checkpoint;
} else {
_locationSource = PuzzleLocationSource.blindBox;
_selectedBlindBoxIndex = 0;
}
}
}

// ---------- Navigation ----------
void _handleBottomNavigation(MysteryLaneTab tab) {
final nav = NavigationService();
switch (tab) {
case MysteryLaneTab.blindBox:
nav.goToBlindBox();
break;
case MysteryLaneTab.missions:
nav.goToMissions();
break;
case MysteryLaneTab.plan:
_showMessage('Plan page will be connected later.');
break;
case MysteryLaneTab.teams:
_showMessage('Teams page will be connected later.');
break;
}
}

void _handleAppNavigation(String tab) {
final nav = NavigationService();
switch (tab) {
case 'missions':
nav.goToMissions();
break;
case 'leaderboard':
nav.goToLeaderboard();
break;
case 'profile':
_openProfile();
break;
default:
if (Navigator.of(context).canPop()) {
Navigator.of(context).pop();
} else {
nav.goHome();
}
}
}

void _goBackFromHeader() {
if (viewMode == 'questions' || viewMode == 'completion') {
setState(() => viewMode = 'categories');
} else {
_handleAppNavigation('missions');
}
}

// ---------- Data loading (full implementations) ----------
Future<void> _loadBlindBoxLocations() async {
if (_isLoadingBlindBoxLocations) return;

setState(() => _isLoadingBlindBoxLocations = true);
try {
final rows = await _supabaseDataSource.getBlindBoxHistory();
final built = <MissionCheckpoint>[];
final seenDestinationIds = <String>{};

for (final row in rows) {
final destinationRaw = row['blind_box_destinations'];
if (destinationRaw is! Map) continue;

final destination = Map<String, dynamic>.from(destinationRaw);
final destinationId = destination['destination_id']?.toString() ?? '';

if (destinationId.isNotEmpty &&
seenDestinationIds.contains(destinationId)) {
continue;
}

if (destinationId.isNotEmpty) {
seenDestinationIds.add(destinationId);
}

built.add(
MissionCheckpoint(
id: destinationId.isNotEmpty ? destinationId : null,
title: destination['name']?.toString() ?? 'Blind Box Destination',
imageUrl: destination['image_url']?.toString(),
locationName: destination['address']?.toString(),
category: 'Blind Box',
epReward: 200,
),
);

if (built.length >= 10) break;
}

if (!mounted) return;
setState(() {
_blindBoxLocations
..clear()
..addAll(built);
_selectedBlindBoxIndex = 0;
_syncLocationFilterAfterLoad();
});
} catch (_) {
// Keep fallback data if history fetch fails.
} finally {
if (mounted) {
setState(() => _isLoadingBlindBoxLocations = false);
}
}
}

Future<void> _loadSavedCheckpointLocations() async {
try {
final rows = await _supabaseDataSource.getSavedPuzzleLocations(
locationSource: 'CHECKPOINT',
);
final currentId = widget.mission?.id;
final built = <MissionCheckpoint>[];
for (final row in rows) {
final raw = row['blind_box_destinations'];
if (raw is! Map) continue;
final destination = Map<String, dynamic>.from(raw);
final id = destination['destination_id']?.toString();
if (id == null || id.isEmpty || id == currentId) continue;
built.add(
MissionCheckpoint(
id: id,
title: destination['name']?.toString() ?? 'Checkpoint location',
imageUrl: destination['image_url']?.toString(),
locationName: destination['address']?.toString(),
category: destination['category']?.toString() ?? 'Checkpoint',
),
);
}
if (!mounted) return;
setState(() {
_savedCheckpointLocations
..clear()
..addAll(built);
});
} catch (error) {
debugPrint('LOAD SAVED CHECKPOINT LOCATIONS ERROR: $error');
}
}

Future<void> _loadPuzzleHistory() async {
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
if (mounted) setState(() => _isLoadingHistory = false);
return;
}

try {
final history = await _challengeService.loadPuzzleHistory(
userId: user.id,
);
if (!mounted) return;
setState(() {
_puzzleHistory = history;
_historyError = null;
_isLoadingHistory = false;
});
} catch (error) {
debugPrint('Puzzle history error: $error');
if (!mounted) return;
setState(() {
_historyError = 'Unable to load puzzle history right now.';
_isLoadingHistory = false;
});
}
}

void _showLocationFilterInfo() {
showDialog<void>(
context: context,
builder: (context) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
title: Row(
children: [
Container(
width: 28,
height: 28,
decoration: BoxDecoration(
color: const Color(0xFFE0F2FE),
shape: BoxShape.circle,
border: Border.all(color: const Color(0xFFBAE6FD)),
),
child: const Icon(
Icons.info_outline_rounded,
size: 16,
color: Color(0xFF0284C7),
),
),
const SizedBox(width: 10),
const Expanded(
child: Text(
'Location Filter',
style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
),
),
],
),
content: const Text(
'Use this filter to switch puzzle context between:\n\n'
'• Blind Box — choose from your previously drawn mystery destinations. '
'The latest draw is selected by default.\n'
'• Checkpoint — use your current checkpoint mission location.\n\n'
'If you have no saved locations, puzzles will run in Random Puzzle mode '
'using questions from the full database.',
style: TextStyle(
fontSize: 13,
height: 1.45,
color: Color(0xFF475569),
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text(
'Got it',
style: TextStyle(
fontWeight: FontWeight.bold,
color: Color(0xFF0284C7),
),
),
),
],
),
);
}

void _showMessage(String message) {
ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(
content: Text(message),
behavior: SnackBarBehavior.floating,
margin: const EdgeInsets.fromLTRB(18, 0, 18, 92),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
);
}

void _replaceWith(Widget page) {
Navigator.of(
context,
).pushReplacement(MaterialPageRoute(builder: (_) => page));
}

Future<void> _loadHeaderProfile() async {
try {
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
if (mounted) setState(() => _headerProfilePictureUrl = null);
return;
}

final profile = await Supabase.instance.client
.from('profiles')
.select('profile_picture_url, exploration_points')
.eq('id', user.id)
.maybeSingle();
if (!mounted) return;

final picture = profile?['profile_picture_url']?.toString().trim();
setState(() {
_headerProfilePictureUrl =
picture != null && picture.isNotEmpty ? picture : null;
_userEp = int.tryParse(
profile?['exploration_points']?.toString() ?? '',
) ??
_userEp;
});
} catch (error) {
debugPrint('PUZZLE HEADER PROFILE PHOTO ERROR: $error');
}
}

Future<void> _openProfile() async {
await Navigator.push(
context,
MaterialPageRoute(builder: (_) => const ProfileScreen()),
);
await _loadHeaderProfile();
}

// ---------- Puzzle logic (full implementations) ----------
void _startQuestionTimer() {
questionTimer?.cancel();

questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
if (!mounted ||
viewMode != 'questions' ||
isSolved ||
_isSubmittingAnswer) {
return;
}

var timeExpired = false;
setState(() {
if (timerSeconds > 0) {
timerSeconds--;
elapsedSeconds++;
timeExpired = timerSeconds == 0;
}
});

if (timeExpired) {
questionTimer?.cancel();
_submitAnswer(timedOut: true);
}
});
}

Future<void> _selectCategory(PuzzleCategory category) async {
if (_isLoadingChallenge) return;

final location = _activeLocationMission;

setState(() {
_isLoadingChallenge = true;
_preparationNotice = null;
selectedCategory = category;
});

try {
final user = Supabase.instance.client.auth.currentUser;

if (user == null) {
_showMessage('Please log in before starting a puzzle challenge.');
return;
}

final questions = await _challengeService.loadChallengeQuestions(
userId: user.id,
destinationId: !_isRandomPuzzleMode
? location?.id : null,
puzzleType: category.key,
historyCategory: category.historyKey,
);

if (!mounted) return;

if (questions.length < 10) {
_showMessage(
'There are not enough questions available for this puzzle type.',
);
return;
}

// Create a new puzzle attempt.
final attemptId = await _challengeService.startAttempt(
userId: user.id,
puzzleType: category.historyKey,
);

if (!mounted) return;

setState(() {
_challengeQuestions = questions;
_challengeQuestionIndex = 0;
_attemptId = attemptId;

questionIndex = 1;
score = 0;
_challengeCompletionTimeSeconds = 0;
_earnedEpForChallenge = 0;
_dailyPuzzleScore = 0;
_dailyLeaderboardRank = null;
_challengeWasRewardEligible = true;
_lastAnswerWasCorrect = false;
_lastAnswerTimedOut = false;
_lastEarnedMarks = 0;
_isSubmittingAnswer = false;
timerSeconds = 30;
elapsedSeconds = 0;

answerInput = '';
selectedOption = null;

hintsAvailable = 3;
hintsUsedCount = 0;

showHintModal = false;
errorMsg = null;
isSolved = false;

// Keep the existing question UI active.
viewMode = 'questions';

// Keep this temporarily for compatibility with
// the existing UI code.
_currentResolvedQuestion = _convertPuzzleQuestionToCategoryQuestion(
questions.first,
);
});

_startQuestionTimer();
} catch (e) {
if (!mounted) return;

setState(() {
_preparationNotice = e is PuzzlePreparationException
? e.message
: 'Puzzles are temporarily unavailable. Your progress is saved. Please retry shortly.';
});
} finally {
if (mounted) {
setState(() {
_isLoadingChallenge = false;
});
}
}
}

CategoryQuestion _convertPuzzleQuestionToCategoryQuestion(
PuzzleQuestion question,
) {
PuzzleCategory category;

switch (question.puzzleType.toLowerCase()) {
case 'image':
case 'image guessing':
case 'image recognition':
category = PuzzleCategory.image;
break;

case 'scrambled':
case 'scrambled word':
case 'scrambled anagrams':
case 'guess the word':
category = PuzzleCategory.scrambled;
break;

case 'word':
case 'word riddle':
case 'word riddle cipher':
case 'missing word':
case 'missing word challenge':
category = PuzzleCategory.word;
break;

case 'mcq':
case 'multiple choice':
case 'multiple choice question':
case 'multiple choice trivia':
category = PuzzleCategory.mcq;
break;

case 'true/false':
case 'true or false':
category = PuzzleCategory.trueFalse;
break;

default:
category = selectedCategory;
}

return CategoryQuestion(
id: question.id,
category: category,
question: question.questionText,
subtitle:
'${categoryInfo[category]?.title ?? 'Puzzle'} · ${question.category}',
answer: question.correctAnswer,
hint: question.hint1 ?? 'No hint available.',
options: question.options.isEmpty ? null : question.options,
imageUrl: question.imageUrl,
locationId: question.destinationId,
displayBoxContent: question.displayBoxContent,
);
}

void _useHint() {
if (isSolved || _isSubmittingAnswer || hintsUsedCount >= 3) {
return;
}

setState(() {
hintsUsedCount++;
hintsAvailable = 3 - hintsUsedCount;
showHintModal = true;
});
}

String _currentHintText() {
if (_challengeQuestions.isEmpty) {
return currentQuestion.hint;
}

final question = _challengeQuestions[_challengeQuestionIndex];
switch (hintsUsedCount) {
case 1:
return question.hint1 ?? 'No hint is available for this question.';
case 2:
return question.hint2 ??
question.hint1 ??
'No further hint is available.';
case 3:
return question.hint3 ?? 'Answer revealed: ${question.correctAnswer}';
default:
return 'No hint is available for this question.';
}
}

Future<void> _submitAnswer({bool timedOut = false}) async {
// Prevent submitting the same question more than once.
if (isSolved || _isSubmittingAnswer) return;

setState(() {
errorMsg = null;
_isSubmittingAnswer = true;
});

final String userAnswer = timedOut
? ''
: (currentQuestion.category == PuzzleCategory.mcq ||
currentQuestion.category == PuzzleCategory.word ||
currentQuestion.category == PuzzleCategory.trueFalse)
? (selectedOption ?? '')
: answerInput.trim();

if (!timedOut && userAnswer.isEmpty) {
setState(() {
errorMsg = 'Please select or provide an answer before submitting.';
_isSubmittingAnswer = false;
});
return;
}

if (_attemptId == null || _challengeQuestions.isEmpty) {
_showMessage(
'Puzzle attempt is not available. Please restart the challenge.',
);
if (mounted) {
setState(() => _isSubmittingAnswer = false);
}
return;
}

final puzzle = _challengeQuestions[_challengeQuestionIndex];

final bool correct =
!timedOut &&
_challengeService.checkAnswer(
userAnswer: userAnswer,
correctAnswer: puzzle.correctAnswer,
);

questionTimer?.cancel();

// -----------------------------------------
// Calculate marks
// -----------------------------------------

final int earnedMarks = _challengeService.calculateQuestionScore(
isCorrect: correct,
remainingTimeSeconds: timerSeconds,
hintsUsed: hintsUsedCount,
);

final remainingTime = timerSeconds < 0 ? 0 : timerSeconds;

final completionTime = elapsedSeconds < 0 ? 0 : elapsedSeconds;

try {
// -----------------------------------------
// Save this question's answer
// -----------------------------------------

await _challengeService.saveQuestionAnswer(
attemptId: _attemptId!,
question: puzzle,
submittedAnswer: userAnswer,
isCorrect: correct,
marksObtained: earnedMarks,
remainingTimeSeconds: remainingTime,
hintsUsed: hintsUsedCount,
);

_challengeCompletionTimeSeconds += completionTime;

// Add this question's score.
score += earnedMarks;

// -----------------------------------------
// Question 10?
// -----------------------------------------

final bool isLastQuestion =
_challengeQuestionIndex >= _challengeQuestions.length - 1;

if (isLastQuestion) {
if (!mounted) return;

setState(() {
isSolved = true;
_lastAnswerWasCorrect = correct;
_lastAnswerTimedOut = timedOut;
_lastEarnedMarks = earnedMarks;
_isSubmittingAnswer = false;
errorMsg = null;
});

// Keep the final result visible long enough to read before opening the
// completion/leaderboard view.
await Future.delayed(const Duration(milliseconds: 2500));

if (!mounted) return;

await _completePuzzleChallenge(
completionTimeSeconds: _challengeCompletionTimeSeconds,
);

if (!mounted) return;

setState(() {
isSolved = true;
_isSubmittingAnswer = false;
viewMode = 'completion';
});

return;
}

// -----------------------------------------
// Move to next question
// -----------------------------------------

if (!mounted) return;

setState(() {
isSolved = true;
_lastAnswerWasCorrect = correct;
_lastAnswerTimedOut = timedOut;
_lastEarnedMarks = earnedMarks;
errorMsg = null;
});

// Small delay so the user can see the result,
// then automatically show the next question.
await Future.delayed(const Duration(milliseconds: 700));

if (!mounted) return;

final previousOffset = _questionScrollController.hasClients
? _questionScrollController.offset
: 0.0;
setState(() {
_challengeQuestionIndex++;
questionIndex = _challengeQuestionIndex + 1;
answerInput = '';
selectedOption = null;
timerSeconds = 30;
elapsedSeconds = 0;
hintsAvailable = 3;
hintsUsedCount = 0;
showHintModal = false;
isSolved = false;
_isSubmittingAnswer = false;
errorMsg = null;
});

WidgetsBinding.instance.addPostFrameCallback((_) {
if (!_questionScrollController.hasClients) return;
final maximum = _questionScrollController.position.maxScrollExtent;
_questionScrollController.jumpTo(previousOffset.clamp(0.0, maximum));
});

_startQuestionTimer();
} catch (e) {
if (!mounted) return;

setState(() {
isSolved = false;
_isSubmittingAnswer = false;
errorMsg = 'Unable to save your answer. Please try again.';
});

debugPrint('Puzzle answer error: $e');
}
}

Future<void> _completePuzzleChallenge({
required int completionTimeSeconds,
}) async {
if (_attemptId == null) return;

final result = await _challengeService.completeAttempt(
attemptId: _attemptId!,
completionTimeSeconds: completionTimeSeconds,
rewardPoints: epReward,
);

score = result.totalScore;
_earnedEpForChallenge = result.pointsEarned;
_dailyPuzzleScore = result.dailyScore;
_dailyLeaderboardRank = result.leaderboardRank;
_rewardedChallengesToday = result.rewardedChallengesToday;
_challengeWasRewardEligible = result.rewardEligible;

if (result.pointsEarned > 0) {
_userEp += result.pointsEarned;
widget.onSolveSuccess?.call(result.pointsEarned);
}
await _loadPuzzleHistory();
}

// ---------- NEW METHOD: _buildPuzzleBody() ----------
Widget _buildPuzzleBody() {
return Stack(
children: [
Column(
children: [
Expanded(
child: AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: _buildCurrentView(),
),
),
],
),
if (_isLoadingChallenge) ...[
const ModalBarrier(dismissible: false, color: Color(0x66000000)),
Center(
child: Semantics(
liveRegion: true,
child: Card(
margin: const EdgeInsets.all(28),
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: const [
CircularProgressIndicator(),
SizedBox(height: 20),
Text(
'Preparing your puzzle…',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w700,
),
),
SizedBox(height: 10),
Text(
'Please wait while we load or generate questions for your selected destination. This may take a little while.',
textAlign: TextAlign.center,
),
],
),
),
),
),
),
],
],
);
}

// ---------- BUILD ----------
@override
Widget build(BuildContext context) {
final nav = NavigationService();

return MysteryLaneLayout(
selectedTab: MysteryLaneTab.missions,
appBarTitle: 'MYSTERYLANE',
profileImageUrl: _headerProfilePictureUrl,
onLeaderboardTap: nav.goToLeaderboard,
onChatTap: () => _showMessage('Chat will be connected later.'),
onProfileTap: nav.goToProfile,
onTabSelected: _handleBottomNavigation,
onHomeTap: nav.goHome,
child: _buildPuzzleBody(),
);
}
  // ============================================================
  // UI BUILDERS (Part 2)
  // ============================================================

  Widget _buildCurrentView() {
    switch (viewMode) {
      case 'questions':
        return _buildQuestionView();
      case 'completion':
        return _buildCompletionView();
      default:
        return _buildCategoriesView();
    }
  }

  Widget _buildCategoriesView() {
    return SingleChildScrollView(
      key: const ValueKey('categories'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMissionHeader(),
          const SizedBox(height: 16),
          _buildHeroBanner(),
          const SizedBox(height: 12),
          if (_isRandomPuzzleMode) ...[
            _buildRandomPuzzleBanner(),
          ] else ...[
            _buildLocationSection(),
          ],
          const SizedBox(height: 12),
          _buildHubTabs(),
          const SizedBox(height: 16),
          if (hubTab == 'selection')
            _buildCategorySelection()
          else
            _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildMissionHeader() {
    return Row(
      children: [
        _roundButton(icon: Icons.arrow_back_rounded, onTap: _goBackFromHeader),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => _handleAppNavigation('missions'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 11),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Checkpoint Mission',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: skyBlue,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    alignment: Alignment.center,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Puzzle Challenge',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.toll_rounded, size: 15, color: skyBlue),
              const SizedBox(width: 4),
              Text(
                '$_userEp',
                style: const TextStyle(
                  color: skyBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner() {
    final selection = hubTab == 'selection';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              border: Border.all(color: Colors.white.withValues(alpha: .20)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'CIPHERS & RIDDLES HUB',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Color(0xFFE0F2FE),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            selection ? 'Select Puzzle Category' : 'Puzzle History',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            selection
                ? 'Choose a challenge format below to solve historical riddles, field ciphers, and trivia to earn EP.'
                : 'Review your past solved ciphers, total scores, completion times, and hint usage statistics.',
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text(
            'Filter Location',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _showLocationFilterInfo,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const Spacer(),
          _locationFilterChip(
            label: 'Blind Box',
            source: PuzzleLocationSource.blindBox,
            icon: Icons.casino_rounded,
          ),
          const SizedBox(width: 6),
          _locationFilterChip(
            label: 'Checkpoint',
            source: PuzzleLocationSource.checkpoint,
            icon: Icons.flag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _locationFilterChip({
    required String label,
    required PuzzleLocationSource source,
    required IconData icon,
  }) {
    final selected = _locationSource == source;

    return InkWell(
      onTap: () {
        if (source == PuzzleLocationSource.blindBox && !_hasBlindBoxLocations) {
          _showMessage('No Blind Box locations available yet.');
          return;
        }
        if (source == PuzzleLocationSource.checkpoint &&
            !_hasCheckpointLocation) {
          if (_savedCheckpointLocations.isNotEmpty) {
            _showLocationPicker();
          } else {
            _showMessage('No checkpoint location has been selected yet.');
          }
          return;
        }

        setState(() {
          _locationSource = source;
          _currentResolvedQuestion = null;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? skyBlue : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? skyBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    if (_locationSource == PuzzleLocationSource.blindBox &&
        _isLoadingBlindBoxLocations &&
        _blindBoxLocations.isEmpty) {
      return _buildLoadingLocationCard('Loading Blind Box locations...');
    }

    if (_showBlindBoxFilterContent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLocationSourceLabel(_locationSource),
          const SizedBox(height: 8),
          _buildLocationCard(),
        ],
      );
    }

    if (_showCheckpointFilterContent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLocationSourceLabel(PuzzleLocationSource.checkpoint),
          const SizedBox(height: 8),
          _buildLocationCard(),
        ],
      );
    }

    final emptyMessage = _locationSource == PuzzleLocationSource.blindBox
        ? 'No Blind Box locations yet. Draw a destination from Blind Box first.'
        : 'No checkpoint mission location available right now.';

    return _buildEmptyLocationState(emptyMessage);
  }

  void _showLocationPicker() {
    if (!_hasCurrentCheckpoint &&
        _savedCheckpointLocations.isEmpty &&
        _blindBoxLocations.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Change puzzle location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  children: [
                    if (_hasCurrentCheckpoint)
                      _locationPickerTile(
                        title: widget.mission!.title,
                        subtitle: 'Current Checkpoint - Recommended',
                        icon: Icons.flag_rounded,
                        selected:
                        _locationSource == PuzzleLocationSource.checkpoint,
                        onTap: () {
                          setState(() {
                            _locationSource = PuzzleLocationSource.checkpoint;
                            _selectedSavedCheckpointIndex = null;
                            _currentResolvedQuestion = null;
                          });
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ...List.generate(_savedCheckpointLocations.length, (index) {
                      final location = _savedCheckpointLocations[index];
                      return _locationPickerTile(
                        title: location.title,
                        subtitle: 'Checkpoint location',
                        icon: Icons.flag_outlined,
                        selected:
                        _locationSource == PuzzleLocationSource.checkpoint &&
                            _selectedSavedCheckpointIndex == index,
                        onTap: () {
                          setState(() {
                            _locationSource = PuzzleLocationSource.checkpoint;
                            _selectedSavedCheckpointIndex = index;
                            _currentResolvedQuestion = null;
                          });
                          Navigator.pop(sheetContext);
                        },
                      );
                    }),
                    ...List.generate(_blindBoxLocations.length, (index) {
                      final location = _blindBoxLocations[index];
                      return _locationPickerTile(
                        title: location.title,
                        subtitle: 'Blind Box location',
                        icon: Icons.casino_rounded,
                        selected:
                        _locationSource == PuzzleLocationSource.blindBox &&
                            _selectedBlindBoxIndex == index,
                        onTap: () {
                          setState(() {
                            _locationSource = PuzzleLocationSource.blindBox;
                            _selectedBlindBoxIndex = index;
                            _currentResolvedQuestion = null;
                          });
                          Navigator.pop(sheetContext);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationPickerTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: selected ? const Color(0xFFF0F9FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? skyBlue : const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: selected
              ? const Color(0xFF0284C7)
              : const Color(0xFFF1F5F9),
          child: Icon(
            icon,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: skyBlue)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _buildLocationSourceLabel(PuzzleLocationSource source) {
    return Row(
      children: [
        Icon(
          source == PuzzleLocationSource.blindBox
              ? Icons.casino_rounded
              : Icons.flag_rounded,
          size: 15,
          color: skyBlue,
        ),
        const SizedBox(width: 6),
        Text(
          source.cardLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildRandomPuzzleBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Random Puzzle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'No puzzle destination was selected. This challenge will use '
                'general Malaysia questions.',
            style: TextStyle(
              color: Color(0xFFEDE9FE),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (_savedCheckpointLocations.isNotEmpty ||
              _blindBoxLocations.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showLocationPicker,
              icon: const Icon(Icons.swap_horiz_rounded, size: 17),
              label: const Text('Choose a saved puzzle location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlindBoxLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a drawn Blind Box location',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _blindBoxLocations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final location = _blindBoxLocations[index];
              final selected = index == _selectedBlindBoxIndex;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedBlindBoxIndex = index;
                    _currentResolvedQuestion = null;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? skyBlue : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? skyBlue : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == 0) ...[
                        Icon(
                          Icons.fiber_new_rounded,
                          size: 14,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        location.title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingLocationCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0F2FE)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLocationState(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final mission = _activeLocationMission;
    if (mission == null) {
      return _buildEmptyLocationState('No location selected.');
    }

    final image =
        mission.imageUrl ??
            'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=400&q=80';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey('${_locationSource.name}-${mission.id ?? mission.title}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0F2FE)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                image,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '📍 ${mission.locationName ?? mission.city ?? mission.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if ((_locationSource == PuzzleLocationSource.checkpoint &&
                _blindBoxLocations.isNotEmpty) ||
                (_locationSource == PuzzleLocationSource.blindBox &&
                    (_blindBoxLocations.length > 1 ||
                        _hasCheckpointLocation))) ...[
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: _showLocationPicker,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Change location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: skyBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHubTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              icon: Icons.key,
              label: 'Select Category',
              active: hubTab == 'selection',
              onTap: () => setState(() => hubTab = 'selection'),
            ),
          ),
          Expanded(
            child: _tabButton(
              icon: Icons.history,
              label: 'Puzzle History',
              active: hubTab == 'history',
              onTap: () => setState(() => hubTab = 'history'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_preparationNotice != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_preparationNotice!),
                  TextButton.icon(
                    onPressed: _isLoadingChallenge
                        ? null : () => _selectCategory(selectedCategory),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry preparation'),
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Available Challenge Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...playablePuzzleCategories.map(_categoryCard),
      ],
    );
  }

  Widget _categoryCard(PuzzleCategory category) {
    final info = categoryInfo[category]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: () => _selectCategory(category),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  border: Border.all(color: const Color(0xFFE0F2FE)),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(info.icon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            info.difficulty,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      info.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_historyError != null) {
      return _buildEmptyLocationState(_historyError!);
    }

    if (_puzzleHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 34, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'No Puzzle History Yet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Complete your first riddle or image cipher to view details here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final filteredHistory = _historyCategoryFilter == null
        ? _puzzleHistory
        : _puzzleHistory
        .where((item) =>
    _categoryFromStoredType(item.puzzleCategory) ==
        _historyCategoryFilter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Puzzle Attempt Log',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            PopupMenuButton<String>(
              tooltip: 'Filter puzzle category',
              initialValue: _historyCategoryFilter?.name ?? 'all',
              onSelected: (value) => setState(() {
                _historyCategoryFilter = value == 'all'
                    ? null
                    : playablePuzzleCategories
                    .where((category) => category.name == value)
                    .firstOrNull;
              }),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'all',
                  child: Text('All categories'),
                ),
                ...playablePuzzleCategories.map(
                      (category) => PopupMenuItem<String>(
                    value: category.name,
                    child: Text(categoryInfo[category]!.title),
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 15,
                      color: skyBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _historyCategoryFilter == null
                          ? 'All categories'
                          : categoryInfo[_historyCategoryFilter]!.title,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: skyBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (filteredHistory.isEmpty)
          _buildEmptyLocationState(
            'No completed challenges in this puzzle category yet.',
          )
        else
          ...filteredHistory.map(_historyCard),
      ],
    );
  }

  Widget _historyCard(PuzzleChallengeHistory item) {
    final historyCategory = _categoryFromStoredType(item.puzzleCategory);
    final historyInfo = historyCategory == null
        ? null
        : categoryInfo[historyCategory];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF0F9FF),
          child: Text(
            historyInfo?.icon ?? '🧩',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          historyInfo?.title ?? item.puzzleCategory,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Destination: ${item.destinationLabel}\n'
              '${_formatHistoryDate(item.completedAt)} · '
              '${item.answers.length} questions · ${item.completionTimeSeconds}s',
          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.totalScore} score',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            Text(
              '+${item.pointsEarned} EP',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF047857),
              ),
            ),
          ],
        ),
        children: List.generate(item.answers.length, (index) {
          final answer = item.answers[index];
          final historyQuestion = _historyQuestionText(
            answer.questionText,
            historyCategory,
          );
          final resultColor = answer.isCorrect
              ? const Color(0xFF047857)
              : const Color(0xFFDC2626);
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${index + 1}: $historyQuestion',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  answer.isCorrect ? 'Correct' : 'Wrong',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: resultColor,
                  ),
                ),
                Text(
                  'Your answer: ${answer.submittedAnswer.isEmpty ? 'No answer' : answer.submittedAnswer}',
                  style: const TextStyle(fontSize: 10),
                ),
                if (!answer.isCorrect)
                  Text(
                    'Correct answer: ${answer.correctAnswer}',
                    style: const TextStyle(fontSize: 10),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${answer.timeTakenSeconds}s · ${answer.hintsUsed} hint(s) · ${answer.marksObtained} score',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatHistoryDate(DateTime? value) {
    if (value == null) return 'Completed';
    final malaysia = value.toUtc().add(const Duration(hours: 8));
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(malaysia.day)}/${two(malaysia.month)}/${malaysia.year} '
        '${two(malaysia.hour)}:${two(malaysia.minute)} MYT';
  }

  String _historyQuestionText(
      String storedQuestion,
      PuzzleCategory? category,
      ) {
    if (category != PuzzleCategory.trueFalse) return storedQuestion;

    final match = RegExp(
      r'^“(.+)” correctly answers: “(.+)”$',
      dotAll: true,
    ).firstMatch(storedQuestion.trim());
    if (match == null) return storedQuestion;

    return '${match.group(2)!}\nAnswer to check: ${match.group(1)!}';
  }

  ({String question, String? answerToCheck}) _trueFalseContent(
      CategoryQuestion question,
      ) {
    if (question.category != PuzzleCategory.trueFalse) {
      return (question: question.question, answerToCheck: null);
    }

    final separateBox = question.displayBoxContent?.trim();
    if (separateBox != null && separateBox.isNotEmpty) {
      return (question: question.question, answerToCheck: separateBox);
    }

    final match = RegExp(
      r'^“(.+)” correctly answers: “(.+)”$',
      dotAll: true,
    ).firstMatch(question.question.trim());
    if (match == null) {
      return (
      question: 'Is the statement below true or false?',
      answerToCheck: question.question,
      );
    }

    return (
    question: match.group(2)!,
    answerToCheck: match.group(1)!,
    );
  }

  Widget _buildQuestionView() {
    final info = categoryInfo[selectedCategory]!;
    final question = currentQuestion;
    final trueFalseContent = _trueFalseContent(question);

    return SingleChildScrollView(
      key: const ValueKey('questions'),
      controller: _questionScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Puzzle Challenge',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              border: Border.all(color: const Color(0xFFBAE6FD)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text(info.icon, style: const TextStyle(fontSize: 21)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Active Challenge Mode',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Tooltip(
                  message:
                  'Challenge locked until all 10 questions are finished',
                  child: Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question $questionIndex / 10',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Score $score',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
                Text(
                  '00:${timerSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                if (question.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      question.imageUrl!,
                      width: double.infinity,
                      height: 175,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 175,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (malaysiaFallbackNotice(_challengeQuestions) != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(malaysiaFallbackNotice(_challengeQuestions)!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF))),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  trueFalseContent.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                if (trueFalseContent.answerToCheck != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ANSWER TO CHECK',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          trueFalseContent.answerToCheck!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (question.category == PuzzleCategory.scrambled) ...[
                  const SizedBox(height: 16),
                  _buildScrambledWordBox(question),
                ],
                const SizedBox(height: 5),
                Text(
                  question.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                if (isSolved)
                  _buildSolvedBanner()
                else
                  _buildAnswerForm(question),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!isSolved) _buildHintFooter(),
          if (!isSolved && showHintModal) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentHintText(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSolvedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _lastAnswerWasCorrect
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
            child: Icon(
              _lastAnswerWasCorrect ? Icons.check : Icons.arrow_forward,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _lastAnswerTimedOut
                ? 'Time is up'
                : _lastAnswerWasCorrect
                ? 'Correct! +$_lastEarnedMarks marks'
                : 'Incorrect! 0 marks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _lastAnswerWasCorrect
                  ? const Color(0xFF064E3B)
                  : const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Your response has been recorded. Loading the next question…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerForm(CategoryQuestion question) {
    final isChoice =
        question.category == PuzzleCategory.mcq ||
            question.category == PuzzleCategory.word ||
            question.category == PuzzleCategory.trueFalse;

    return Column(
      children: [
        if (isChoice && question.options != null)
          ...question.options!.map(
                (option) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => selectedOption = option),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(14),
                  backgroundColor: selectedOption == option
                      ? const Color(0xFFF0F9FF)
                      : const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: selectedOption == option
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selectedOption == option
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
        if (!isChoice)
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => answerInput = value,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitAnswer(),
                  decoration: InputDecoration(
                    hintText: 'Your answer',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: Icons.arrow_forward,
                background: const Color(0xFF0284C7),
                foreground: Colors.white,
                onTap: _submitAnswer,
              ),
            ],
          ),
        if (isChoice)
          _primaryButton(
            label: 'Submit Answer',
            icon: Icons.arrow_forward,
            disabled: selectedOption == null,
            onTap: _submitAnswer,
          ),
        if (errorMsg != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Color(0xFFBE123C),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    errorMsg!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9F1239),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHintFooter() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, size: 17, color: Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Hints available: $hintsAvailable / 3',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          TextButton(
            onPressed: hintsUsedCount >= 3 ? null : _useHint,
            child: Text(
              hintsUsedCount >= 3
                  ? 'All hints used'
                  : showHintModal
                  ? 'Next Hint'
                  : 'View Hint',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    final info = categoryInfo[selectedCategory]!;

    return SingleChildScrollView(
      key: const ValueKey('completion'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              _roundButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => setState(() => viewMode = 'categories'),
              ),
              const Expanded(
                child: Text(
                  'Challenge Completed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0284C7),
                  Color(0xFF0369A1),
                  Color(0xFF0F172A),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFFFBBF24),
                  child: Icon(
                    Icons.emoji_events,
                    size: 36,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'EXCELLENT DECODE!',
                  style: TextStyle(
                    color: Color(0xFFFCD34D),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Challenge Mastered',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${info.title} • ${_activeLocationMission?.city ?? _activeLocationMission?.title ?? 'Random Puzzle'}',
                  style: const TextStyle(
                    color: Color(0xFFBAE6FD),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _metricCard('Total Score', '$score'),
                    const SizedBox(width: 5),
                    _metricCard('EP Earned', '+$_earnedEpForChallenge'),
                    const SizedBox(width: 5),
                    _metricCard(
                      'Daily Rank',
                      _dailyLeaderboardRank == null
                          ? '—'
                          : '#$_dailyLeaderboardRank',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _challengeWasRewardEligible
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _challengeWasRewardEligible
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Text(
              _challengeWasRewardEligible
                  ? 'Today: $_dailyPuzzleScore puzzle points • '
                  '$_rewardedChallengesToday of 5 scoring challenges used.'
                  : 'You have completed today’s 5 scoring challenges. '
                  'You can keep playing, but this challenge does not add '
                  'points or change your daily ranking.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _primaryButton(
            label: 'Play Another Puzzle Challenge',
            icon: Icons.refresh,
            onTap: () {
              setState(() {
                viewMode = 'categories';
                hubTab = 'selection';
              });
            },
          ),
          const SizedBox(height: 10),
          _secondaryAction(
            label: 'View Leaderboard',
            icon: Icons.emoji_events_rounded,
            background: const Color(0xFFF59E0B),
            foreground: const Color(0xFF0F172A),
            onTap: () => _handleAppNavigation('leaderboard'),
          ),
          const SizedBox(height: 10),
          _secondaryAction(
            label: 'Continue to Achievement & Community Contribution',
            icon: Icons.workspace_premium,
            onTap: () => _handleAppNavigation('profile'),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFBAE6FD),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFFCD34D),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    bool disabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF94A3B8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: .8,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 7),
              Icon(icon, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _secondaryAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color background = Colors.white,
    Color foreground = const Color(0xFF334155),
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 1,
        ),
      ),
    );
  }

  // ---------- Small helpers ----------
  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 21, color: const Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: background),
        ),
        child: Icon(icon, size: 18, color: foreground),
      ),
    );
  }

  Widget _smallBadge(String text, {Color textColor = const Color(0xFF0284C7)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  PuzzleCategory? _categoryFromStoredType(String value) {
    switch (value.trim().toLowerCase()) {
      case 'scrambled':
      case 'scrambled word':
      case 'scrambled anagrams':
      case 'guess the word':
        return PuzzleCategory.scrambled;
      case 'word':
      case 'word riddle':
      case 'word riddle cipher':
      case 'missing word':
      case 'missing word challenge':
        return PuzzleCategory.word;
      case 'mcq':
      case 'multiple choice':
      case 'multiple choice question':
      case 'multiple choice trivia':
        return PuzzleCategory.mcq;
      case 'true/false':
      case 'true or false':
        return PuzzleCategory.trueFalse;
      default:
        return null;
    }
  }

  Widget _buildScrambledWordBox(CategoryQuestion question) {
    final savedBox = question.displayBoxContent?.trim();
    final scrambled = savedBox != null && savedBox.isNotEmpty
        ? savedBox
        : _scrambleAnswer(question.answer, question.id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'ARRANGE THESE LETTERS',
            style: TextStyle(
              color: Color(0xFF0284C7),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            scrambled.split('').join('  '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _scrambleAnswer(String answer, String questionId) {
    final clean = answer.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length < 2) return clean;

    final letters = clean.split('');
    final random = Random(questionId.hashCode ^ clean.hashCode);
    for (var attempt = 0; attempt < 5; attempt++) {
      letters.shuffle(random);
      final result = letters.join();
      if (result != clean) return result;
    }

    return '${clean.substring(1)}${clean[0]}';
  }
}
