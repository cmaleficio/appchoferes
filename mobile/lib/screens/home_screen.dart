import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/local_expense.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  final _storage = const FlutterSecureStorage();
  List<LocalExpense> _expenses = [];
  bool _loading = true;
  double _balance = 0;
  double _exchangeRate = 0;
  bool _syncing = false;
  String _userName = '';

  static const _categoryColors = {
    'gasolina': Color(0xFFFF9800),
    'peaje': Color(0xFF2196F3),
    'hotel': Color(0xFF9C27B0),
    'otros': Color(0xFF9E9E9E),
  };

  static const _categoryIcons = {
    'gasolina': Icons.local_gas_station,
    'peaje': Icons.toll,
    'hotel': Icons.hotel,
    'otros': Icons.receipt,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _userName = await _storage.read(key: 'user_name') ?? 'Chofer';
      final all = await _db.getAllExpenses();
      await _loadRate();
      await _loadBalance();
      if (!mounted) return;
      setState(() {
        _expenses = all;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final token = await SyncService.instance.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${SyncService.instance.getBaseUrl()}/api/expenses/my-summary'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final backendBalance = _safeDouble(data['balance']);
        final localUnsynced = await _db.getTotalUnsyncedAmountBs();
        double bal = backendBalance;
        if (_exchangeRate > 0 && localUnsynced > 0) {
          bal = backendBalance - localUnsynced / _exchangeRate;
        }
        if (!mounted) return;
        setState(() => _balance = _safeDouble(bal));
      }
    } catch (_) {}
  }

  Future<void> _loadRate() async {
    try {
      final token = await SyncService.instance.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${SyncService.instance.getBaseUrl()}/api/exchange-rates/current'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rate = _safeDouble(data['rate']);
        if (!mounted) return;
        setState(() => _exchangeRate = rate);
      }
    } catch (_) {}
  }

  double _safeDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) {
      final d = v.toDouble();
      return d.isNaN || d.isInfinite ? 0 : d;
    }
    return 0;
  }

  List<LocalExpense> get _last4 {
    if (_expenses.length <= 4) return _expenses;
    return _expenses.sublist(0, 4);
  }

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};
    for (final e in _expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amountBs;
    }
    return totals;
  }

  double get _grandTotal => _categoryTotals.values.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final bsFormat = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('AppChoferes'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'Sincronizar',
            onPressed: _syncing ? null : _sync,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Historial completo',
            onPressed: () => Navigator.pushNamed(context, '/expenses').then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await SyncService.instance.clearToken();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome
                  Text('¡Hola, $_userName!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Balance card
                  Card(
                    color: _balance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _balance >= 0 ? Icons.account_balance_wallet : Icons.warning_amber,
                            size: 32,
                            color: _balance >= 0 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saldo disponible',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              Text(
                                _balance.isNaN || _balance.isInfinite ? '\$0.00' : currency.format(_balance),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Last 4 movements
                  Text('Últimos movimientos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_last4.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text('No hay gastos registrados', style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      ),
                    )
                  else
                    ..._last4.map((e) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (_categoryColors[e.category] ?? Colors.grey).withAlpha(38),
                              child: Icon(_categoryIcons[e.category] ?? Icons.receipt,
                                  color: _categoryColors[e.category] ?? Colors.grey, size: 20),
                            ),
                            title: Text(e.category == 'gasolina' ? 'Gasolina'
                                    : e.category == 'peaje' ? 'Peaje'
                                    : e.category == 'hotel' ? 'Hotel'
                                    : 'Otros',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(e.description ?? dateFmt.format(e.createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Bs. ${e.amountBs.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('\$${(e.amountBs / (e.exchangeRate > 0 ? e.exchangeRate : 1)).toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        )),

                  const SizedBox(height: 20),

                  // Distribution chart
                  Text('Distribución de gastos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_categoryTotals.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text('Sin gastos para mostrar', style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      ),
                    )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Bar chart
                              ..._categoryTotals.entries.map((entry) {
                                final pct = _grandTotal > 0 ? entry.value / _grandTotal * 100 : 0;
                                final color = _categoryColors[entry.key] ?? Colors.grey;
                                final label = entry.key == 'gasolina' ? 'Gasolina'
                                    : entry.key == 'peaje' ? 'Peaje'
                                    : entry.key == 'hotel' ? 'Hotel'
                                    : 'Otros';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 12, height: 12,
                                                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(label, style: const TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                          Text('Bs. ${entry.value.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          color: color,
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_expense',
        onPressed: () => Navigator.pushNamed(context, '/expense/new').then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Gasto'),
      ),
    );
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final sync = SyncService.instance;
      final token = await sync.getToken();
      if (token == null) return;
      await sync.fullSync(token);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sincronización completada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}
