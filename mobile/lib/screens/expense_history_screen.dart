import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/local_expense.dart';
import '../services/database_service.dart';

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
    'gasolina': '⛽ Gasolina',
    'peaje': '🛣️ Peaje',
    'hotel': '🏨 Hotel',
    'otros': '📌 Otros',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _db.getAllExpenses();
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
      _filtered.fold(0.0, (s, e) => s + e.amount);

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'gasolina': return Icons.local_gas_station;
      case 'peaje': return Icons.toll;
      case 'hotel': return Icons.hotel;
      default: return Icons.receipt;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'gasolina': return Colors.orange;
      case 'peaje': return Colors.blue;
      case 'hotel': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
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
                          onSelected: (_) => setState(() => _filterCategory = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ${currency.format(_totalFiltered)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _filtered[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _categoryColor(e.category).withOpacity(0.15),
                                child: Icon(_categoryIcon(e.category), color: _categoryColor(e.category)),
                              ),
                              title: Text(_categoryLabels[e.category] ?? e.category),
                              subtitle: Text([
                                if (e.description != null) e.description!,
                                dateFmt.format(e.createdAt),
                                if (!e.synced) '⏳ Pendiente de sincronizar',
                              ].join(' · ')),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(currency.format(e.amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (e.amountBs != null && e.exchangeRate != null)
                                    Text('Bs. ${e.amountBs!.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
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
