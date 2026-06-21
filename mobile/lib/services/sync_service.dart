import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/local_expense.dart';

class SyncService {
  static final SyncService _instance = SyncService._();
  static SyncService get instance => _instance;
  SyncService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _baseUrlKey = 'api_base_url';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  String _baseUrl = 'http://10.0.2.2:8000';

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    await _storage.write(key: _baseUrlKey, value: url);
  }

  String getBaseUrl() => _baseUrl;
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<int?> getUserId() async {
    final v = await _storage.read(key: _userIdKey);
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> saveUserId(int id) =>
      _storage.write(key: _userIdKey, value: id.toString());

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Upload unsynced expenses using multipart (sends binary files when present).
  Future<SyncResult> syncExpenses(String token) async {
    final db = DatabaseService.instance;
    final unsynced = await db.getUnsyncedExpenses();
    if (unsynced.isEmpty) return SyncResult(isEmpty: true);

    int synced = 0;
    int failed = 0;

    for (final exp in unsynced) {
      try {
        final hasFiles = exp.receiptImagePath != null || exp.audioPath != null;

        if (hasFiles) {
          // Use multipart upload for expenses with binary files
          final uri = Uri.parse('$_baseUrl/api/expenses/upload');
          final request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer $token';
          request.fields['category'] = exp.category;
          request.fields['amount_bs'] = exp.amountBs.toString();
          request.fields['exchange_rate'] = exp.exchangeRate.toString();
          if (exp.description != null) {
            request.fields['description'] = exp.description!;
          }
          if (exp.isMultipleTolls != null) {
            request.fields['is_multiple_tolls'] = exp.isMultipleTolls.toString();
          }
          if (exp.tollCount != null) {
            request.fields['toll_count'] = exp.tollCount.toString();
          }

          if (exp.receiptImagePath != null &&
              File(exp.receiptImagePath!).existsSync()) {
            request.files.add(await http.MultipartFile.fromPath(
              'receipt_image',
              exp.receiptImagePath!,
            ));
          }
          if (exp.audioPath != null && File(exp.audioPath!).existsSync()) {
            request.files.add(await http.MultipartFile.fromPath(
              'audio_description',
              exp.audioPath!,
            ));
          }

          final streamed = await request.send();
          final res = await http.Response.fromStream(streamed);
          if (res.statusCode == 201 || res.statusCode == 200) {
            final serverId = jsonDecode(res.body)['id'].toString();
            await db.markSynced(exp.id, serverId);
            synced++;
          } else {
            failed++;
          }
        } else {
          // JSON upload for expenses without files
          final body = {
            'category': exp.category,
            'amount_bs': exp.amountBs,
            'exchange_rate': exp.exchangeRate,
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
        }
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }

  /// Upload unsynced tracks, then clear them from local DB.
  Future<SyncResult> syncTracks(String token) async {
    final db = DatabaseService.instance;
    final unsynced = await db.getUnsyncedTracks();
    if (unsynced.isEmpty) return SyncResult(isEmpty: true);

    int synced = 0;
    int failed = 0;

    final userId = await getUserId();
    final batch = unsynced
        .map((t) => {
              'latitude': t.latitude,
              'longitude': t.longitude,
              'battery_level': t.batteryLevel,
              'recorded_at': t.timestamp.toIso8601String(),
            })
        .toList();

    try {
      final body = {
        'user_id': userId ?? 0,
        'points': batch,
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/api/telemetry/track'),
        headers: _headers(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await db.markTracksSynced(unsynced.map((t) => t.id).toList());
        // Clear synced tracks to free local storage
        await db.clearSyncedTracks();
        synced = unsynced.length;
      } else {
        failed = unsynced.length;
      }
    } catch (_) {
      failed = unsynced.length;
    }

    return SyncResult(synced: synced, failed: failed);
  }

  /// Download expenses from backend and save locally (skip duplicates by serverId).
  Future<void> downloadExpenses(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/expenses/my'),
        headers: _headers(token),
      );
      if (res.statusCode != 200) return;
      final list = jsonDecode(res.body) as List;
      final db = DatabaseService.instance;
      for (final item in list) {
        final serverId = item['id'].toString();
        final existing = await db.getExpenseByServerId(serverId);
        if (existing != null) continue;
        final createdAt = item['created_at'] != null
            ? DateTime.tryParse(item['created_at']) ?? DateTime.now()
            : DateTime.now();
        final expense = LocalExpense(
          serverId: serverId,
          category: item['category'] ?? 'otros',
          amount: (item['amount'] as num?)?.toDouble() ?? 0,
          amountBs: (item['amount_bs'] as num?)?.toDouble() ?? 0,
          exchangeRate: (item['exchange_rate'] as num?)?.toDouble() ?? 1,
          description: item['description'] as String?,
          isMultipleTolls: item['is_multiple_tolls'] as bool?,
          tollCount: item['toll_count'] as int?,
          createdAt: createdAt,
          synced: true,
          syncedAt: DateTime.now(),
        );
        await db.saveExpense(expense);
      }
    } catch (_) {}
  }

  /// Request an edit for a synced expense.
  Future<bool> requestEdit(String token, int expenseId, String reason) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/expenses/request-edit'),
        headers: _headers(token),
        body: jsonEncode({
          'expense_id': expenseId,
          'reason': reason,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> fullSync(String token) async {
    await syncExpenses(token);
    await syncTracks(token);
    await downloadExpenses(token);
  }
}

class SyncResult {
  final bool isEmpty;
  final int synced;
  final int failed;

  SyncResult({this.isEmpty = false, this.synced = 0, this.failed = 0});
}
