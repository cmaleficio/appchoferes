import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._();
  static SyncService get instance => _instance;
  SyncService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _baseUrlKey = 'api_base_url';
  static const String _tokenKey = 'auth_token';

  String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator → host

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    await _storage.write(key: _baseUrlKey, value: url);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Sync unsynced expenses to the backend.
  Future<SyncResult> syncExpenses(String token) async {
    final db = DatabaseService.instance;
    final unsynced = await db.getUnsyncedExpenses();
    if (unsynced.isEmpty) return SyncResult(isEmpty: true);

    int synced = 0;
    int failed = 0;

    for (final exp in unsynced) {
      try {
        final body = {
          'category': exp.category,
          'amount': exp.amount,
          if (exp.amountBs != null) 'amount_bs': exp.amountBs,
          if (exp.exchangeRate != null) 'exchange_rate': exp.exchangeRate,
          if (exp.description != null) 'description': exp.description,
          if (exp.isMultipleTolls != null)
            'is_multiple_tolls': exp.isMultipleTolls,
          if (exp.tollCount != null) 'toll_count': exp.tollCount,
        };

        final res = await http.post(
          Uri.parse('$_baseUrl/api/expenses/'),
          headers: _headers(token),
          body: jsonEncode(body),
        );

        if (res.statusCode == 201 || res.statusCode == 200) {
          final serverId = jsonDecode(res.body)['id'].toString();
          await db.markSynced(exp.id, serverId);
          synced++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }

  /// Sync unsynced GPS tracks to the backend.
  Future<SyncResult> syncTracks(String token) async {
    final db = DatabaseService.instance;
    final unsynced = await db.getUnsyncedTracks();
    if (unsynced.isEmpty) return SyncResult(isEmpty: true);

    int synced = 0;
    int failed = 0;

    final batch = unsynced
        .map((t) => {
              'latitude': t.latitude,
              'longitude': t.longitude,
              'battery_level': t.batteryLevel,
              'recorded_at': t.timestamp.toIso8601String(),
            })
        .toList();

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/telemetry/track'),
        headers: _headers(token),
        body: jsonEncode({'points': batch}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await db.markTracksSynced(unsynced.map((t) => t.id).toList());
        synced = unsynced.length;
      } else {
        failed = unsynced.length;
      }
    } catch (_) {
      failed = unsynced.length;
    }

    return SyncResult(synced: synced, failed: failed);
  }

  /// Full sync: expenses + tracks.
  Future<void> fullSync(String token) async {
    await syncExpenses(token);
    await syncTracks(token);
  }
}

class SyncResult {
  final bool isEmpty;
  final int synced;
  final int failed;

  SyncResult({this.isEmpty = false, this.synced = 0, this.failed = 0});
}
