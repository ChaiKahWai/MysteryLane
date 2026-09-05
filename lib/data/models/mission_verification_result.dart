class MissionVerificationResult {
  final String result;
  final String verificationResult;
  final String reason;
  final double confidence;

  const MissionVerificationResult({
    required this.result,
    required this.verificationResult,
    required this.reason,
    required this.confidence,
  });

  bool get passed =>
      result.toUpperCase() == 'PASS';

  bool get failed =>
      result.toUpperCase() == 'FAIL';

  bool get uncertain =>
      result.toUpperCase() == 'UNCERTAIN';

  factory MissionVerificationResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return MissionVerificationResult(
      result:
      json['result']
          ?.toString() ??
          'UNCERTAIN',

      verificationResult:
      json['verificationResult']
          ?.toString() ??
          'REJECTED',

      reason:
      json['reason']
          ?.toString() ??
          'Unable to verify the mission photo.',

      confidence:
      _toDouble(
        json['confidence'],
      ),
    );
  }

  static double _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0;
  }
}