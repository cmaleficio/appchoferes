import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/local_track.dart';
import 'database_service.dart';

Position? _bgLastPosition;

class BackgroundTrackingService {
  static final BackgroundTrackingService _instance =
      BackgroundTrackingService._();
  static BackgroundTrackingService get instance => _instance;
  BackgroundTrackingService._();

  static const String _channelId = 'appchoferes_tracking';
  static const String _channelDesc =
      'AppChoferes está registrando tu ubicación';

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'AppChoferes',
        initialNotificationContent: 'Registrando ubicación...',
        foregroundServiceNotificationId: 888,
        onStart: onStart,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'AppChoferes',
        content: 'Tracking activo',
      );
    }

    Timer.periodic(const Duration(seconds: 30), (_) async {
      final battery = Battery();
      double batteryLevel = 100;
      try {
        batteryLevel = (await battery.batteryLevel).toDouble();
      } catch (_) {}

      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        }
      } catch (_) {}

      if (position == null) return;

      if (_bgLastPosition != null) {
        final dist = Geolocator.distanceBetween(
          _bgLastPosition!.latitude,
          _bgLastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (dist < 50) return;
      }

      _bgLastPosition = position;

      final track = LocalTrack(
        latitude: position.latitude,
        longitude: position.longitude,
        batteryLevel: batteryLevel,
        timestamp: DateTime.now(),
      );

      await DatabaseService.instance.saveTrack(track);

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'AppChoferes',
          content:
              '📍 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} · 🔋${batteryLevel.toStringAsFixed(0)}%',
        );
      }
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }

  Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  Future<bool> isRunning() async =>
      FlutterBackgroundService().isRunning();
}
