import 'package:flutter/foundation.dart';

import '../../data/datasources/location_data_source.dart';
import '../../data/models/checkpoint_destination.dart';
import '../../data/repositories/checkpoint_repository.dart';
import '../services/checkpoint_service.dart';

class CheckpointController extends ChangeNotifier {
  final CheckpointService _service;

  CheckpointController({
    required CheckpointService service,
  }) : _service = service;

  factory CheckpointController.production() {
    return CheckpointController(
      service: CheckpointService(
        repository: CheckpointRepository(),
        locationDataSource: LocationDataSource(),
      ),
    );
  }

  // ============================================================
  // UI STATE
  // Controller owns the state directly.
  // No separate state file.
  // ============================================================

  bool isLoading = true;

  String? errorMessage;

  double? currentLatitude;
  double? currentLongitude;

  List<CheckpointDestination> nearbyDestinations = [];

  Set<String> completedDestinationIds = {};

  Map<String, double> distanceKmByDestinationId = {};

  Map<String, int> rewardPointsByDestinationId = {};

  CheckpointDestination? selectedDestination;

  String? headerProfilePictureUrl;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    await Future.wait([
      reload(),
      loadHeaderProfile(),
    ]);
  }

  // ============================================================
  // LOAD CHECKPOINTS
  // ============================================================

  Future<void> reload() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final result =
      await _service.loadNearbyCheckpoints(
        selectedDestinationId:
        selectedDestination?.destinationId,
      );

      currentLatitude =
          result.latitude;

      currentLongitude =
          result.longitude;

      nearbyDestinations =
          result.nearbyDestinations;

      completedDestinationIds =
          result.completedDestinationIds;

      distanceKmByDestinationId =
          result.distanceKmByDestinationId;

      rewardPointsByDestinationId =
          result.rewardPointsByDestinationId;

      selectedDestination =
          result.selectedDestination;
    } catch (error) {
      errorMessage = error
          .toString()
          .replaceFirst(
        'LocationException: ',
        '',
      )
          .replaceFirst(
        'Exception: ',
        '',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> loadHeaderProfile() async {
    try {
      headerProfilePictureUrl =
      await _service
          .getCurrentProfilePictureUrl();

      notifyListeners();
    } catch (error) {
      debugPrint(
        'Checkpoint header profile error: $error',
      );
    }
  }

  // ============================================================
  // SELECT DESTINATION
  // ============================================================

  void selectDestination(
      CheckpointDestination destination,
      ) {
    selectedDestination =
        destination;

    notifyListeners();
  }

  // ============================================================
  // COMPLETED CHECKPOINTS
  // ============================================================

  Future<void> refreshCompleted() async {
    try {
      completedDestinationIds =
      await _service
          .loadCompletedDestinationIds();

      notifyListeners();
    } catch (error) {
      debugPrint(
        'Completed checkpoint refresh error: '
            '$error',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool isCompleted(
      CheckpointDestination destination,
      ) {
    return completedDestinationIds
        .contains(
      destination.destinationId,
    );
  }

  bool isBlindBoxDestination(
      CheckpointDestination destination,
      ) {
    return _service
        .isBlindBoxDestination(
      destination,
    );
  }

  String sourceLabel(
      CheckpointDestination destination,
      ) {
    return _service.sourceLabel(
      destination,
    );
  }

  double distanceKm(
      CheckpointDestination destination,
      ) {
    return distanceKmByDestinationId[
    destination.destinationId] ??
        0;
  }

  int rewardPoints(
      CheckpointDestination destination,
      ) {
    return rewardPointsByDestinationId[
    destination.destinationId] ??
        0;
  }
}