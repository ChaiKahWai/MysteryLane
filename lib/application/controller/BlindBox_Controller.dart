import '../../data/models/blind_box_history.dart';
import '../services/blind_box_service.dart';
export '../models/blind_box_history.dart';

/// ============================================================================
/// APPLICATION / LOGIC LAYER
/// ============================================================================
///
/// Presentation (BlindBox_Screen.dart)
///             ↓
/// Application (this controller)
///             ↓
/// Data
/// ├── LocationDataSource
/// ├── GooglePlacesDataSource
/// └── SupabaseDataSource
///
/// This controller owns the Blind Box application rules:
/// - radius validation
/// - random destination selection
/// - no-repeat filtering
/// - photo + description preparation
/// - destination persistence
/// - DRAW / REDRAW history persistence
/// - history loading for the UI
class BlindBoxController {
  static const int maxBlindBoxChances =
      BlindBoxService.maxBlindBoxChances;

  static const int blindBoxChanceCostEp =
      BlindBoxService.blindBoxChanceCostEp;

  final BlindBoxService _service;

  BlindBoxController({
    required BlindBoxService service,
  }) : _service = service;

  // ADD THIS
  /// Run with:
  /// flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY
  factory BlindBoxController.production() {
    return BlindBoxController(
      service: BlindBoxService.production(),
    );
  }

  Future<BlindBoxBalance> loadBlindBoxBalance() {
    return _service.loadBlindBoxBalance();
  }

  Future<BlindBoxBalance> buyBlindBoxChance() {
    return _service.buyBlindBoxChance();
  }

  Future<BlindBoxResult> drawBlindBox({
    required double radiusKm,
    Set<String> recentPlaceIds = const <String>{},
  }) {
    return _service.drawBlindBox(
      radiusKm: radiusKm,
      recentPlaceIds: recentPlaceIds,
    );
  }

  Future<BlindBoxResult> redrawBlindBox({
    required double radiusKm,
    required String currentPlaceId,
    Set<String> recentPlaceIds = const <String>{},
  }) {
    return _service.redrawBlindBox(
      radiusKm: radiusKm,
      currentPlaceId: currentPlaceId,
      recentPlaceIds: recentPlaceIds,
    );
  }

  Future<List<BlindBoxHistoryResult>>
  loadBlindBoxHistory() {
    return _service.loadBlindBoxHistory();
  }

  void dispose() {
    _service.dispose();
  }

}