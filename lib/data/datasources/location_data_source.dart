import 'package:geolocator/geolocator.dart';

class LocationDataSource {
  /// Gets the user's current GPS position.
  ///
  /// Data Layer responsibility:
  /// - check whether location service is enabled
  /// - check/request permission
  /// - return latitude/longitude through Position
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationException(
        'Location service is disabled. Please turn on GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. '
            'Please enable it from device settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw LocationException(
        'Unable to get current location: $e',
      );
    }
  }
}

class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
