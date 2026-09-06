import 'package:geolocator/geolocator.dart';

import '../../data/datasources/location_data_source.dart';
import '../../data/models/checkpoint_destination.dart';
import '../../data/repositories/checkpoint_repository.dart';

class CheckpointLoadResult {
  final double latitude;
  final double longitude;

  final List<CheckpointDestination>
  nearbyDestinations;

  final Set<String>
  completedDestinationIds;

  final Map<String, double>
  distanceKmByDestinationId;

  final Map<String, int>
  rewardPointsByDestinationId;

  final CheckpointDestination?
  selectedDestination;

  const CheckpointLoadResult({
    required this.latitude,
    required this.longitude,
    required this.nearbyDestinations,
    required this.completedDestinationIds,
    required this.distanceKmByDestinationId,
    required this.rewardPointsByDestinationId,
    required this.selectedDestination,
  });
}

class CheckpointService {
  static const double checkpointRadiusMeters =
  5000.0;

  final CheckpointRepository _repository;

  final LocationDataSource _locationDataSource;

  CheckpointService({
    required CheckpointRepository repository,
    required LocationDataSource locationDataSource,
  })  : _repository = repository,
        _locationDataSource =
            locationDataSource;

  // ============================================================
  // LOAD CHECKPOINT MAP
  //
  // RULE:
  //
  // CURATED / HIDDEN GEM
  // → only within 5 km
  //
  // GOOGLE / BLIND BOX
  // → current user's Blind Box destination
  // → show regardless of distance
  // ============================================================

  Future<CheckpointLoadResult>
  loadNearbyCheckpoints({
    String? selectedDestinationId,
  }) async {
    // ==========================================================
    // 1. CURRENT LOCATION
    // ==========================================================

    final Position position =
    await _locationDataSource
        .getCurrentLocation();

    // ==========================================================
    // 2. ACTIVE CHECKPOINT DESTINATIONS
    //
    // Repository should already make Blind Box destinations
    // user-specific.
    // ==========================================================

    final ActiveCheckpointData activeData =
    await _repository
        .getActiveCheckpointDestinations();

    // ==========================================================
    // 3. CURRENT USER COMPLETED CHECKPOINTS
    // ==========================================================

    final Set<String> completedIds =
    await _repository
        .getCompletedDestinationIds();

    final List<CheckpointDestination>
    visibleDestinations =
    <CheckpointDestination>[];

    final Map<String, double>
    distanceMap =
    <String, double>{};

    // ==========================================================
    // 4. FILTER DESTINATIONS
    // ==========================================================

    for (final CheckpointDestination destination
    in activeData.destinations) {
      final double distanceMeters =
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        destination.latitude,
        destination.longitude,
      );

      final double distanceKm =
          distanceMeters / 1000.0;

      // Save distance for both Hidden Gem
      // and Blind Box destinations.
      distanceMap[
      destination.destinationId] =
          distanceKm;

      final bool isBlindBox =
      isBlindBoxDestination(
        destination,
      );

      // --------------------------------------------------------
      // BLIND BOX
      //
      // No 5 km restriction.
      // Repository already decides whether this Blind Box
      // belongs to the current user.
      // --------------------------------------------------------

      if (isBlindBox) {
        visibleDestinations.add(
          destination,
        );

        continue;
      }

      // --------------------------------------------------------
      // CURATED / HIDDEN GEM
      //
      // Must be within 5 km.
      // --------------------------------------------------------

      if (distanceMeters <=
          checkpointRadiusMeters) {
        visibleDestinations.add(
          destination,
        );
      }
    }

    // ==========================================================
    // 5. SORT
    //
    // Still sort nearest first.
    //
    // A Blind Box destination can therefore appear later in
    // the collection if it is far away.
    // ==========================================================

    visibleDestinations.sort(
          (
          CheckpointDestination a,
          CheckpointDestination b,
          ) {
        final double distanceA =
            distanceMap[
            a.destinationId] ??
                double.infinity;

        final double distanceB =
            distanceMap[
            b.destinationId] ??
                double.infinity;

        return distanceA.compareTo(
          distanceB,
        );
      },
    );

    // ==========================================================
    // 6. SELECT DESTINATION
    //
    // Important for:
    // Blind Box History
    // → VIEW ON CHECKPOINT MAP
    // ==========================================================

    CheckpointDestination? selected;

    if (selectedDestinationId != null &&
        selectedDestinationId
            .trim()
            .isNotEmpty) {
      for (final destination
      in visibleDestinations) {
        if (destination.destinationId ==
            selectedDestinationId) {
          selected = destination;

          break;
        }
      }
    }

    // Normal Checkpoint map opening.

    // ==========================================================
    // 7. RETURN
    // ==========================================================

    return CheckpointLoadResult(
      latitude:
      position.latitude,

      longitude:
      position.longitude,

      nearbyDestinations:
      visibleDestinations,

      completedDestinationIds:
      completedIds,

      distanceKmByDestinationId:
      distanceMap,

      rewardPointsByDestinationId:
      activeData.rewardPoints,

      selectedDestination:
      selected,
    );
  }

  // ============================================================
  // COMPLETED
  // ============================================================

  Future<Set<String>>
  loadCompletedDestinationIds() {
    return _repository
        .getCompletedDestinationIds();
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<String?>
  getCurrentProfilePictureUrl() {
    return _repository
        .getCurrentProfilePictureUrl();
  }

  // ============================================================
  // BLIND BOX SOURCE
  // ============================================================

  bool isBlindBoxDestination(
      CheckpointDestination destination,
      ) {
    final String source =
        destination.destinationSource
            ?.trim()
            .toUpperCase() ??
            '';

    return source == 'GOOGLE';
  }

  // ============================================================
  // SOURCE LABEL
  // ============================================================

  String sourceLabel(
      CheckpointDestination destination,
      ) {
    if (isBlindBoxDestination(
      destination,
    )) {
      return 'BLIND BOX';
    }

    return 'HIDDEN GEM';
  }
}