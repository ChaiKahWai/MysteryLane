import '../../data/models/checkpoint_destination.dart';

class CompleteMissionPuzzleData {
  final String destinationId;
  final String title;
  final String? imageUrl;
  final String? locationName;
  final String category;

  const CompleteMissionPuzzleData({
    required this.destinationId,
    required this.title,
    required this.imageUrl,
    required this.locationName,
    required this.category,
  });
}

class CompleteMissionController {
  final CheckpointDestination destination;

  final String title;
  final int reward;
  final int totalPoints;

  final String? photoPath;
  final String? verificationReason;
  final double? verificationConfidence;

  const CompleteMissionController({
    required this.destination,
    required this.title,
    required this.reward,
    required this.totalPoints,
    this.photoPath,
    this.verificationReason,
    this.verificationConfidence,
  });

  // ===========================================================================
  // AI CONFIDENCE
  // ===========================================================================

  int get confidencePercent {
    final double value =
        verificationConfidence ?? 0;

    // Gemini may return:
    // 0.95 -> 95%
    // OR
    // 95 -> 95%
    if (value <= 1) {
      return (value * 100)
          .round()
          .clamp(
        0,
        100,
      );
    }

    return value
        .round()
        .clamp(
      0,
      100,
    );
  }

  // ===========================================================================
  // VERIFICATION MESSAGE
  // ===========================================================================

  String get verificationReasonText {
    final String value =
        verificationReason
            ?.trim() ??
            '';

    if (value.isNotEmpty) {
      return value;
    }

    return 'The submitted photo satisfies the checkpoint mission requirement.';
  }

  // ===========================================================================
  // PUZZLE DATA
  // ===========================================================================

  CompleteMissionPuzzleData get puzzleData {
    final dynamic rawCategory =
        destination.category;

    final String category =
        rawCategory
            ?.toString()
            .trim() ??
            '';

    return CompleteMissionPuzzleData(
      destinationId:
      destination.destinationId,

      title:
      destination.name,

      imageUrl:
      destination.imageUrl,

      locationName:
      destination.address,

      category:
      category.isNotEmpty
          ? category
          : 'Checkpoint',
    );
  }
}