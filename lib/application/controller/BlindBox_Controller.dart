import '../services/blind_box_service.dart';
import '../../data/models/blind_box_history.dart';
export '../models/blind_box_history.dart';


class BlindBoxController {
  final BlindBoxService _service;

  // ===========================================================================
  // CONSTANTS EXPOSED TO UI
  // ===========================================================================

  static const double minRadiusKm =
      BlindBoxService.minRadiusKm;

  static const double maxRadiusKm =
      BlindBoxService.maxRadiusKm;

  static const int maxBlindBoxChances =
      BlindBoxService.maxBlindBoxChances;

  static const int maxDailyBlindBoxPurchases =
      BlindBoxService
          .maxDailyBlindBoxPurchases;

  static const int blindBoxChanceCostEp =
      BlindBoxService
          .blindBoxChanceCostEp;

  BlindBoxController({
    required BlindBoxService service,
  }) : _service = service;

  /// Production constructor.
  ///
  /// BlindBoxService.production() creates:
  /// - GooglePlacesDataSource
  /// - LocationDataSource
  /// - SupabaseDataSource
  factory BlindBoxController.production() {
    return BlindBoxController(
      service:
      BlindBoxService.production(),
    );
  }

  // ===========================================================================
  // BALANCE
  // ===========================================================================

  Future<BlindBoxBalance>
  loadBlindBoxBalance() {
    return _service
        .loadBlindBoxBalance();
  }

  // ===========================================================================
  // PURCHASE STATUS
  // ===========================================================================

  /// Used before displaying the chance-purchase dialog.
  ///
  /// Returned Map contains:
  ///
  /// exploration_points
  /// blind_box_chances
  /// purchased_today
  /// daily_remaining
  /// holding_remaining
  /// daily_limit
  /// max_chances
  /// chance_cost_ep
  Future<Map<String, int>>
  loadBlindBoxPurchaseStatus() {
    return _service
        .loadBlindBoxPurchaseStatus();
  }

  // ===========================================================================
  // BUY MULTIPLE CHANCES
  // ===========================================================================

  Future<BlindBoxBalance>
  buyBlindBoxChances({
    required int quantity,
  }) {
    return _service
        .buyBlindBoxChances(
      quantity: quantity,
    );
  }

  // ===========================================================================
  // LEGACY SINGLE BUY
  // ===========================================================================

  /// Keeps older UI code working.
  Future<BlindBoxBalance>
  buyBlindBoxChance() {
    return buyBlindBoxChances(
      quantity: 1,
    );
  }

  // ===========================================================================
  // DRAW
  // ===========================================================================

  Future<BlindBoxResult>
  drawBlindBox({
    required double radiusKm,
    Set<String> recentPlaceIds =
    const <String>{},
  }) {
    return _service.drawBlindBox(
      radiusKm: radiusKm,
      recentPlaceIds:
      recentPlaceIds,
    );
  }

  // ===========================================================================
  // REDRAW
  // ===========================================================================

  Future<BlindBoxResult>
  redrawBlindBox({
    required double radiusKm,
    required String currentPlaceId,
    Set<String> recentPlaceIds =
    const <String>{},
  }) {
    return _service.redrawBlindBox(
      radiusKm: radiusKm,
      currentPlaceId:
      currentPlaceId,
      recentPlaceIds:
      recentPlaceIds,
    );
  }

  // ===========================================================================
  // DRAW HISTORY
  // ===========================================================================

  Future<List<BlindBoxHistoryResult>>
  loadBlindBoxHistory() {
    return _service
        .loadBlindBoxHistory();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  void dispose() {
    _service.dispose();
  }
}