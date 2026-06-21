import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';

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

class GpsService {
  static final GpsService _instance = GpsService._();
  static GpsService get instance => _instance;
  GpsService._();

  final Battery _battery = Battery();
  StreamSubscription<Position>? _subscription;
  GpsLocation? _lastLocation;

  Future<double> _getBattery() async {
    try {
      return (await _battery.batteryLevel).toDouble();
    } catch (_) {
      return 100;
    }
  }

  Future<GpsLocation?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final battery = await _getBattery();
      final loc = GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        batteryLevel: battery,
      );
      _lastLocation = loc;
      return loc;
    } catch (e) {
      debugPrint('[GPS] getCurrentLocation error: $e');
      return null;
    }
  }

  Future<void> startListening() async {
    stopListening();
    try {
      _subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        _lastLocation = GpsLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      });
    } catch (e) {
      debugPrint('[GPS] startListening error: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  GpsLocation? get lastLocation => _lastLocation;
}
