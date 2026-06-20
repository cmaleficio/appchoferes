import 'dart:async';
import 'package:flutter/foundation.dart';

/// GPS location data.
class GpsLocation {
  final double latitude;
  final double longitude;
  final double? batteryLevel;
  final DateTime timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    this.batteryLevel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Service for capturing GPS location.
///
/// Uses `geolocator` or `location` package in production.
/// This scaffold provides the interface; wire real GPS in android/app/build.gradle.
class GpsService {
  static final GpsService _instance = GpsService._();
  static GpsService get instance => _instance;
  GpsService._();

  StreamSubscription? _subscription;
  GpsLocation? _lastLocation;

  /// Returns the current location (or a fallback for development).
  Future<GpsLocation?> getCurrentLocation() async {
    // In production: replace with Geolocator.getCurrentPosition()
    // For now, return a mock so the app doesn't crash.
    debugPrint('[GPS] getCurrentLocation called — wire geolocator package');
    return null;
  }

  /// Start listening to location updates.
  Future<void> startListening() async {
    // In production: Geolocator.getPositionStream(...).listen(...)
    debugPrint('[GPS] startListening called');
  }

  /// Stop listening.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  GpsLocation? get lastLocation => _lastLocation;
}
