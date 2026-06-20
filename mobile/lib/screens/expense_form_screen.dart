import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/local_expense.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../widgets/expense_category_dropdown.dart';
import '../widgets/toll_fields.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService.instance;

  String _category = 'gasolina';
  double _amount = 0;
  double? _amountBs;
  double? _exchangeRate;
  String? _description;
  String? _receiptPath;
  bool? _isMultipleTolls;
  int? _tollCount;

  bool _saving = false;
  double _estimatedBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final totalToday = await _db.getTotalExpensesToday();
    // Estimate: driver gets $5000/month budget, ~$167/day
    final dailyBudget = 5000.0 / 30;
    if (mounted) {
      setState(() => _estimatedBalance = dailyBudget - totalToday);
    }
  }

  Future<void> _takePhoto() async {
    final path = await CameraService.instance.takeReceiptPhoto();
    if (path != null) setState(() => _receiptPath = path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final expense = LocalExpense(
        category: _category,
        amount: _amount,
        amountBs: _amountBs,
        exchangeRate: _exchangeRate,
        description: _description,
        receiptImagePath: _receiptPath,
        isMultipleTolls: _category == 'peaje' ? _isMultipleTolls : null,
        tollCount: _category == 'peaje' && _isMultipleTolls == true
            ? _tollCount
            : null,
      );

      await _db.saveExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gasto guardado localmente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Gasto'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance card
            Card(
              color: _estimatedBalance >= 0
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _estimatedBalance >= 0
                          ? Icons.account_balance_wallet
                          : Icons.warning_amber,
                      color:
                          _estimatedBalance >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo estimado del día',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_estimatedBalance),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _estimatedBalance >= 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            ExpenseCategoryDropdown(
              value: _category,
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Monto (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _amount = double.tryParse(v) ?? 0,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el monto';
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return 'Monto inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amount Bs (optional)
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Monto en Bs. (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _amountBs = double.tryParse(v),
            ),
            const SizedBox(height: 16),

            // Exchange rate (optional)
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Tasa BCV (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _exchangeRate = double.tryParse(v),
            ),
            const SizedBox(height: 16),

            // Toll-specific fields
            if (_category == 'peaje') ...[
              TollFields(
                isMultipleTolls: _isMultipleTolls,
                tollCount: _tollCount,
                onMultipleTollsChanged: (v) =>
                    setState(() => _isMultipleTolls = v),
                onTollCountChanged: (v) => setState(() => _tollCount = v),
              ),
              const SizedBox(height: 16),
            ],

            // Description
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
              onChanged: (v) => _description = v,
            ),
            const SizedBox(height: 16),

            // Receipt photo
            Card(
              child: InkWell(
                onTap: _takePhoto,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                  ),
                  child: _receiptPath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_receiptPath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                  onPressed: () =>
                                      setState(() => _receiptPath = null),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Tomar foto del comprobante',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
