class CheckpointMission {
  final String missionId;
  final String destinationId;

  final String missionName;
  final String objective;

  final int verificationRadiusM;
  final bool photoRequired;
  final int rewardPoints;

  final String? completionInstructions;
  final String? photoRequirement;

  final String generatedBy;
  final String difficultyLevel;

  final bool isActive;

  const CheckpointMission({
    required this.missionId,
    required this.destinationId,
    required this.missionName,
    required this.objective,
    required this.verificationRadiusM,
    required this.photoRequired,
    required this.rewardPoints,
    this.completionInstructions,
    this.photoRequirement,
    required this.generatedBy,
    required this.difficultyLevel,
    required this.isActive,
  });

  factory CheckpointMission.fromJson(
      Map<String, dynamic> json,
      ) {
    return CheckpointMission(
      missionId:
      json['mission_id']?.toString() ?? '',

      destinationId:
      json['destination_id']?.toString() ?? '',

      missionName:
      json['mission_name']?.toString() ??
          'Checkpoint Mission',

      objective:
      json['objective']?.toString() ?? '',

      verificationRadiusM:
      _parseInt(
        json['verification_radius_m'],
      ),

      photoRequired:
      json['photo_required'] as bool? ?? true,

      rewardPoints:
      _parseInt(
        json['reward_points'],
      ),

      completionInstructions:
      json['completion_instructions']
          ?.toString(),

      photoRequirement:
      json['photo_requirement']
          ?.toString(),

      generatedBy:
      json['generated_by']?.toString() ??
          'MANUAL',

      difficultyLevel:
      json['difficulty_level']
          ?.toString() ??
          'EASY',

      isActive:
      json['is_active'] as bool? ?? true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }
}