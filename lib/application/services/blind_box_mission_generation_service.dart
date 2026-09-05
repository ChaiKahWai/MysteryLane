import 'package:flutter/foundation.dart';

import 'package:mysterylane/core/config/supabase_config.dart';
import 'package:mysterylane/data/models/checkpoint_destination.dart';

class GeneratedCheckpointMissionResult {
  final String missionId;
  final bool generated;
  final CheckpointDestination destination;

  const GeneratedCheckpointMissionResult({
    required this.missionId,
    required this.generated,
    required this.destination,
  });
}

class BlindBoxMissionGenerationService {
  Future<GeneratedCheckpointMissionResult> generateMissionForBlindBox({
    required String googlePlaceId,
    required String name,
    String? description,
    String? category,
    String? imageUrl,
    required double latitude,
    required double longitude,
    required String formattedAddress,
    double? rating,
  }) async {
    try {
      if (googlePlaceId.trim().isEmpty) {
        throw Exception('Google Place ID is missing.');
      }

      if (name.trim().isEmpty) {
        throw Exception('Destination name is missing.');
      }

      debugPrint(
        '[MISSION GENERATION] Calling Gemini for $name ($googlePlaceId)',
      );

      final response = await SupabaseConfig.client.functions.invoke(
        'generate-checkpoint-mission',
        body: {
          'googlePlaceId': googlePlaceId.trim(),
          'name': name.trim(),
          'description': description?.trim(),
          'category': category?.trim(),
          'imageUrl': imageUrl?.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'formattedAddress': formattedAddress.trim(),
          'rating': rating,
        },
      );

      debugPrint(
        '[MISSION GENERATION] Status: ${response.status}',
      );
      debugPrint(
        '[MISSION GENERATION] Data: ${response.data}',
      );

      if (response.status < 200 || response.status >= 300) {
        final dynamic data = response.data;

        if (data is Map) {
          String message = data['error']?.toString() ??
              'Unable to generate checkpoint mission.';

          if (data['details'] != null) {
            message += '\n${data['details']}';
          }

          throw Exception(message);
        }

        throw Exception('Unable to generate checkpoint mission.');
      }

      if (response.data == null || response.data is! Map) {
        throw Exception('Mission generation returned invalid data.');
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(response.data as Map);

      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      final dynamic destinationRaw = data['destination'];
      final dynamic missionRaw = data['mission'];

      if (destinationRaw is! Map) {
        throw Exception('Generated destination data is missing.');
      }

      if (missionRaw is! Map) {
        throw Exception('Generated mission data is missing.');
      }

      final Map<String, dynamic> destinationJson =
      Map<String, dynamic>.from(destinationRaw);
      final Map<String, dynamic> missionJson =
      Map<String, dynamic>.from(missionRaw);

      final String missionId =
          missionJson['mission_id']?.toString() ?? '';

      if (missionId.isEmpty) {
        throw Exception('Generated mission ID is missing.');
      }

      final CheckpointDestination destination =
      CheckpointDestination.fromJson(destinationJson);

      return GeneratedCheckpointMissionResult(
        missionId: missionId,
        generated: data['generated'] == true,
        destination: destination,
      );
    } catch (error) {
      debugPrint(
        '[MISSION GENERATION] Error: $error',
      );
      rethrow;
    }
  }
}
