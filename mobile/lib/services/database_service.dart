import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_expense.dart';
import '../models/local_track.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();

  late Isar isar;
  bool _initialized = false;

  DatabaseService._();

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [LocalExpenseSchema, LocalTrackSchema],
      directory: dir.path,
      inspector: kDebugMode,
    );
    _initialized = true;
  }

  // ─── Expenses ──────────────────────────────────────────────

  Future<int> saveExpense(LocalExpense expense) =>
      isar.writeTxn(() => isar.localExpenses.put(expense));

  Future<List<LocalExpense>> getUnsyncedExpenses() =>
      isar.localExpenses.where().filter().syncedEqualTo(false).findAll();

  Future<List<LocalExpense>> getAllExpenses() =>
      isar.localExpenses.where().sortByCreatedAtDesc().findAll();

  Future<double> getTotalExpensesTodayBs() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final expenses = await isar.localExpenses
        .where()
        .createdAtBetween(start, end)
        .findAll();
    double total = 0;
    for (final e in expenses) {
      total += e.amountBs;
    }
    return total;
  }

  Future<double> getTotalUnsyncedAmountBs() async {
    final unsynced = await getUnsyncedExpenses();
    double total = 0;
    for (final e in unsynced) {
      total += e.amountBs;
    }
    return total;
  }

  Future<LocalExpense?> getExpenseByServerId(String serverId) =>
      isar.localExpenses.where().serverIdEqualTo(serverId).findFirst();

  Future<void> markSynced(int localId, String serverId) =>
      isar.writeTxn(() async {
        final exp = await isar.localExpenses.get(localId);
        if (exp != null) {
          exp.synced = true;
          exp.serverId = serverId;
          exp.syncedAt = DateTime.now();
          await isar.localExpenses.put(exp);
        }
      });

  // ─── Tracks ────────────────────────────────────────────────

  Future<int> saveTrack(LocalTrack track) =>
      isar.writeTxn(() => isar.localTracks.put(track));

  Future<List<LocalTrack>> getUnsyncedTracks() =>
      isar.localTracks.where().filter().syncedEqualTo(false).findAll();

  Future<void> markTracksSynced(List<int> ids) =>
      isar.writeTxn(() async {
        for (final id in ids) {
          final t = await isar.localTracks.get(id);
          if (t != null) {
            t.synced = true;
            t.syncedAt = DateTime.now();
            await isar.localTracks.put(t);
          }
        }
      });

  /// Delete all synced tracks to free local storage.
  Future<void> clearSyncedTracks() =>
      isar.writeTxn(() async {
        final synced = await isar.localTracks
            .where()
            .filter()
            .syncedEqualTo(true)
            .findAll();
        await isar.localTracks.deleteAll(synced.map((t) => t.id).toList());
      });
}
