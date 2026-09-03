import '../../data/models/blind_box_history.dart';
import '../services/blind_box_service.dart';
export '../models/blind_box_history.dart';
import '../services/blind_box_service.dart';

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