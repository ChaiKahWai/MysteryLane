import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mysterylane/core/config/supabase_config.dart';
import 'package:mysterylane/data/models/mission_verification_result.dart';

class MissionPhotoVerificationService {
  Future<MissionVerificationResult>
  verifyMissionPhoto({
    required String userMissionId,
    required XFile photo,
  }) async {
    try {
      // ========================================================
      // READ PHOTO
      // ========================================================

      final Uint8List bytes =
      await photo.readAsBytes();

      debugPrint(
        'MISSION PHOTO SIZE: '
            '${(bytes.length / 1024).toStringAsFixed(2)} KB',
      );

      // Prevent oversized Edge Function request.
      if (bytes.length >
          15 * 1024 * 1024) {
        throw Exception(
          'The mission photo is too large. '
              'Please capture another photo.',
        );
      }

      // ========================================================
      // CONVERT PHOTO TO BASE64
      // ========================================================

      final String imageBase64 =
      base64Encode(bytes);

      // ========================================================
      // DETERMINE MIME TYPE
      // ========================================================

      final String mimeType =
      _getMimeType(photo);

      debugPrint(
        'MISSION PHOTO MIME TYPE: $mimeType',
      );

      debugPrint(
        'CALLING verify-mission-photo...',
      );

      // ========================================================
      // CALL SUPABASE EDGE FUNCTION
      // ========================================================

      final response =
      await SupabaseConfig
          .client
          .functions
          .invoke(
        'verify-mission-photo',
        body: {
          'userMissionId':
          userMissionId,

          'imageBase64':
          imageBase64,

          'mimeType':
          mimeType,
        },
      );

      debugPrint(
        'EDGE FUNCTION STATUS: '
            '${response.status}',
      );

      debugPrint(
        'EDGE FUNCTION DATA: '
            '${response.data}',
      );

      // ========================================================
      // HTTP ERROR
      // ========================================================

      if (response.status < 200 ||
          response.status >= 300) {
        final dynamic data =
            response.data;

        if (data is Map &&
            data['error'] != null) {
          throw Exception(
            data['error'].toString(),
          );
        }

        throw Exception(
          'Gemini photo verification failed.',
        );
      }

      // ========================================================
      // EMPTY RESPONSE
      // ========================================================

      if (response.data == null) {
        throw Exception(
          'Gemini returned an empty response.',
        );
      }

      // ========================================================
      // CONVERT RESPONSE
      // ========================================================

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        response.data as Map,
      );

      if (data['error'] != null) {
        throw Exception(
          data['error'].toString(),
        );
      }

      return MissionVerificationResult
          .fromJson(data);
    } catch (error) {
      debugPrint(
        'MISSION PHOTO VERIFICATION ERROR: '
            '$error',
      );

      rethrow;
    }
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

  String _getMimeType(
      XFile photo,
      ) {
    final String? originalMime =
        photo.mimeType;

    if (originalMime != null &&
        originalMime.isNotEmpty) {
      return originalMime;
    }

    final String path =
    photo.path.toLowerCase();

    if (path.endsWith('.png')) {
      return 'image/png';
    }

    if (path.endsWith('.webp')) {
      return 'image/webp';
    }

    if (path.endsWith('.heic')) {
      return 'image/heic';
    }

    if (path.endsWith('.heif')) {
      return 'image/heif';
    }

    return 'image/jpeg';
  }
}