import 'package:isar/isar.dart';

part 'local_track.g.dart';

@collection
class LocalTrack {
  Id id = Isar.autoIncrement;

  double latitude;
  double longitude;
  double batteryLevel;

  @Index()
  DateTime timestamp;

  bool synced = false;
  DateTime? syncedAt;

  LocalTrack({
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    DateTime? timestamp,
    this.synced = false,
    this.syncedAt,
  }) : timestamp = timestamp ?? DateTime.now();
}
