import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/local_expense.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  final _db = DatabaseService.instance;
  List<LocalExpense> _expenses = [];
  String _filterCategory = 'todas';
  bool _loading = true;

  static const _categoryLabels = {
    'todas': 'Todas',
    'gasolina': 'Gasolina',
    'peaje': 'Peaje',
    'hotel': 'Hotel',
    'otros': 'Otros',
  };

  static const _categoryColors = {
    'gasolina': Colors.orange,
    'peaje': Colors.blue,
    'hotel': Colors.purple,
    'otros': Colors.grey,
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
    setState(() => _loading = true);
    final all = await _db.getAllExpenses();
    if (!mounted) return;
    setState(() {
      _expenses = all;
      _loading = false;
    });
  }

  List<LocalExpense> get _filtered {
    if (_filterCategory == 'todas') return _expenses;
    return _expenses.where((e) => e.category == _filterCategory).toList();
  }

  double get _totalFiltered =>
      _filtered.fold(0.0, (s, e) => s + e.amountBs);

  Future<void> _requestEdit(LocalExpense expense) async {
    final serverId = expense.serverId;
    if (serverId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El gasto debe sincronizarse primero'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar Edición'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motivo de la edición',
            border: OutlineInputBorder(),
            hintText: 'Ej: El monto es incorrecto...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            child: const Text('Enviar Solicitud'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    final token = await SyncService.instance.getToken();
    if (token == null) return;

    final ok = await SyncService.instance.requestEdit(
      token,
      int.parse(serverId),
      result.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✅ Solicitud de edición enviada'
              : '❌ Error al enviar solicitud'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bsFormat = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Gastos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Filter chips + total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categoryLabels.entries.map((entry) {
                      final selected = _filterCategory == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _filterCategory = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ${bsFormat.format(_totalFiltered)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No hay gastos registrados'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _filtered[i];
                            return Dismissible(
                              key: ValueKey(e.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.blue,
                                child: const Icon(Icons.edit_note,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                await _requestEdit(e);
                                return false; // never actually dismiss
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      (_categoryColors[e.category] ?? Colors.grey).withAlpha(38),
                                  child: Icon(_categoryIcons[e.category] ?? Icons.receipt,
                                      color: _categoryColors[e.category] ?? Colors.grey),
                                ),
                                title: Text(_categoryLabels[e.category] ??
                                    e.category),
                                subtitle: Text([
                                  if (e.description != null) e.description!,
                                  dateFmt.format(e.createdAt),
                                  if (!e.synced) '⏳ Pendiente de sincronizar',
                                ].join(' · ')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Bs. ${e.amountBs.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          '\$${(e.amountBs / (e.exchangeRate > 0 ? e.exchangeRate : 1)).toStringAsFixed(2)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    if (e.synced) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _requestEdit(e),
                                        child: Icon(Icons.edit_note,
                                            size: 24,
                                            color: Colors.blue.shade400),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
