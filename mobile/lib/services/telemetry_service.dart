import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/local_track.dart';
import 'database_service.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._();
  static TelemetryService get instance => _instance;
  TelemetryService._();

  final Battery _battery = Battery();
  Timer? _timer;
  bool _running = false;

  Position? _lastPosition;

  static const Duration _interval = Duration(minutes: 5);
  static const double _minDistanceMeters = 100;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    // Capture immediately on start
    await _capture();

    // Then every 5 minutes
    _timer = Timer.periodic(_interval, (_) => _capture());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<double> _getBatteryLevel() async {
    try {
      return (await _battery.batteryLevel).toDouble();
    } catch (_) {
      return 100;
    }
  }

  Future<void> _capture() async {
    try {
      final batteryLevel = await _getBatteryLevel();

      final position = await Geolocator.getLastKnownPosition();
      final currentPosition = position;

      // Skip if within min distance of last capture
      if (_lastPosition != null && currentPosition != null) {
        final dist = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          currentPosition.latitude,
          currentPosition.longitude,
        );
        if (dist < _minDistanceMeters) return;
      }

      if (currentPosition == null) {
        // No cached position, try getting fresh one
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (fresh == null) return;
        _lastPosition = fresh;
      } else {
        _lastPosition = currentPosition;
      }

      final track = LocalTrack(
        latitude: _lastPosition!.latitude,
        longitude: _lastPosition!.longitude,
        batteryLevel: batteryLevel,
        timestamp: DateTime.now(),
      );

      await DatabaseService.instance.saveTrack(track);
    } catch (_) {
      // Silently fail – offline‑first, retry on next cycle
    }
  }

  void dispose() {
    stop();
  }
}
