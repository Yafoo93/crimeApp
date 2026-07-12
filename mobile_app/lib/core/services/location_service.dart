import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationCaptureStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

class LocationCaptureResult {
  const LocationCaptureResult._({
    required this.status,
    this.position,
    this.message,
  });

  factory LocationCaptureResult.success(Position position) {
    return LocationCaptureResult._(
      status: LocationCaptureStatus.success,
      position: position,
    );
  }

  factory LocationCaptureResult.failure(
    LocationCaptureStatus status,
    String message,
  ) {
    return LocationCaptureResult._(status: status, message: message);
  }

  final LocationCaptureStatus status;
  final Position? position;
  final String? message;

  bool get isSuccess => status == LocationCaptureStatus.success;
}

/// Wraps GPS permission and capture handling so callers only deal with a
/// typed result instead of platform-specific permission/service exceptions.
class LocationService {
  Future<LocationCaptureResult> captureCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationCaptureResult.failure(
        LocationCaptureStatus.serviceDisabled,
        'Location services are turned off on this device.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return LocationCaptureResult.failure(
        LocationCaptureStatus.permissionDenied,
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationCaptureResult.failure(
        LocationCaptureStatus.permissionDeniedForever,
        'Location permission is permanently denied. Enable it from app settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationCaptureResult.success(position);
    } on TimeoutException {
      return LocationCaptureResult.failure(
        LocationCaptureStatus.timeout,
        'Getting your location took too long. Try again or enter GhanaPostGPS manually.',
      );
    } catch (_) {
      return LocationCaptureResult.failure(
        LocationCaptureStatus.error,
        'Could not get your location. Try again or enter GhanaPostGPS manually.',
      );
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
