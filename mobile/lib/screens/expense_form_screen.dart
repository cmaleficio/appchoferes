import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/local_expense.dart';
import '../models/local_track.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/camera_service.dart';
import '../services/gps_service.dart';
import '../services/audio_service.dart';
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
  final _gps = GpsService.instance;
  final _audio = AudioService.instance;

  String _category = 'gasolina';
  double _amountBs = 0;
  double _exchangeRate = 0;
  String? _description;
  String? _receiptPath;
  String? _audioPath;
  bool _isRecording = false;
  bool? _isMultipleTolls;
  int? _tollCount;
  GpsLocation? _capturedLocation;
  bool _gpsCaptured = false;
  String? _gpsLabel;

  bool _saving = false;
  double _balance = 0;
  bool _loadingRate = true;

  @override
  void initState() {
    super.initState();
    _loadRate();
    _captureGps();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    final loc = await _gps.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() {
        _capturedLocation = loc;
        _gpsCaptured = true;
        _gpsLabel =
            '📍 ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}';
      });
      await _db.saveTrack(LocalTrack(
        latitude: loc.latitude,
        longitude: loc.longitude,
        batteryLevel: loc.batteryLevel ?? 100,
        timestamp: DateTime.now(),
      ));
    } else {
      if (mounted) {
        setState(() => _gpsLabel = '📍 GPS no disponible');
      }
    }
  }

  Future<void> _loadRate() async {
    try {
      final token = await SyncService.instance.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse(
            '${SyncService.instance.getBaseUrl()}/api/exchange-rates/current'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _exchangeRate = (data['rate'] as num).toDouble();
          _loadingRate = false;
        });
        await _loadBalance();
      } else {
        setState(() => _loadingRate = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRate = false);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final token = await SyncService.instance.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse(
            '${SyncService.instance.getBaseUrl()}/api/expenses/my-summary'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final backendBalance = (data['balance'] as num).toDouble();
        final localUnsynced = await _db.getTotalUnsyncedAmountBs();
        if (_exchangeRate > 0) {
          setState(() =>
              _balance = backendBalance - (localUnsynced / _exchangeRate));
        } else {
          setState(() => _balance = backendBalance);
        }
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    final path = await CameraService.instance.takeReceiptPhoto();
    if (path != null && mounted) setState(() => _receiptPath = path);
  }

  Future<void> _toggleAudio() async {
    if (_isRecording) {
      final path = await _audio.stopRecording();
      if (path != null && mounted) {
        setState(() {
          _audioPath = path;
          _isRecording = false;
        });
      }
    } else {
      final path = await _audio.startRecording();
      if (path != null && mounted) {
        setState(() {
          _audioPath = path;
          _isRecording = true;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tomar la foto del comprobante primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_exchangeRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay tasa BCV disponible. Contacta al administrador'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final usdAmount = _amountBs / _exchangeRate;
      final expense = LocalExpense(
        category: _category,
        amount: usdAmount,
        amountBs: _amountBs,
        exchangeRate: _exchangeRate,
        description: _description,
        receiptImagePath: _receiptPath,
        audioPath: _audioPath,
        isMultipleTolls: _category == 'peaje' ? _isMultipleTolls : null,
        tollCount: _category == 'peaje' && _isMultipleTolls == true
            ? _tollCount
            : null,
        createdAt: DateTime.now(),
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
    final bsFormat = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2);

    final bool canSubmit = _receiptPath != null && _exchangeRate > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Gasto'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Guardar',
                    style: TextStyle(
                      color: canSubmit ? null : Colors.grey,
                    ),
                  ),
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
              color: _balance >= 0
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _balance >= 0
                          ? Icons.account_balance_wallet
                          : Icons.warning_amber,
                      color:
                          _balance >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_balance),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _balance >= 0
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

            // GPS indicator
            if (_gpsLabel != null)
              Card(
                color: _gpsCaptured
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _gpsCaptured ? Icons.gps_fixed : Icons.gps_off,
                        size: 20,
                        color:
                            _gpsCaptured ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(_gpsLabel!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700)),
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

            // Amount in Bs
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Monto en Bs.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _amountBs = double.tryParse(v) ?? 0,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el monto en Bs.';
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return 'Monto inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Exchange rate (auto-fetched, read-only)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _loadingRate
                          ? const Text('Cargando tasa BCV...',
                              style: TextStyle(fontSize: 13))
                          : Text(
                              'Tasa BCV: Bs. ${_exchangeRate.toStringAsFixed(2)} / USD',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Auto-calculated USD amount
            if (!_loadingRate && _exchangeRate > 0 && _amountBs > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Text(
                  '≈ ${currencyFormat.format(_amountBs / _exchangeRate)} USD',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 12),

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

            // Receipt photo (required before submit)
            Card(
              child: InkWell(
                onTap: _takePhoto,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _receiptPath != null
                        ? Colors.transparent
                        : Colors.orange.shade50,
                    border: _receiptPath == null
                        ? Border.all(color: Colors.orange.shade300, width: 2)
                        : null,
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
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '✅ Comprobante',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 48, color: Colors.orange.shade700),
                            const SizedBox(height: 8),
                            Text(
                              'OBLIGATORIO: Tomar foto del comprobante',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toca aquí para abrir la cámara',
                              style: TextStyle(
                                  color: Colors.orange.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            if (_receiptPath == null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  '* Debes tomar la foto para poder guardar el gasto',
                  style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 16),

            // Audio description (optional)
            Card(
              child: InkWell(
                onTap: _toggleAudio,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: _isRecording ? Colors.red : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isRecording
                                  ? 'Grabando... (toca para detener)'
                                  : _audioPath != null
                                      ? '✅ Audio grabado'
                                      : 'Grabar descripción por voz',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _isRecording
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _isRecording
                                    ? Colors.red
                                    : Colors.grey.shade800,
                              ),
                            ),
                            if (_isRecording)
                              Text(
                                'Toca de nuevo para detener',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                      if (_audioPath != null && !_isRecording)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          onPressed: () =>
                              setState(() => _audioPath = null),
                        ),
                      if (_isRecording)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
