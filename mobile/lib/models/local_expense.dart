import 'package:isar/isar.dart';

part 'local_expense.g.dart';

@collection
class LocalExpense {
  Id id = Isar.autoIncrement;

  @Index()
  String? serverId;

  String category; // peaje | hotel | gasolina | otros
  double amount;    // USD (computed: amountBs / exchangeRate)
  double amountBs;  // required — primary amount in Bs
  double exchangeRate; // required — BCV rate for the date
  String? description;
  String? receiptImagePath;
  String? audioPath;

  bool? isMultipleTolls;
  int? tollCount;

  @Index()
  DateTime createdAt;

  bool synced = false;
  DateTime? syncedAt;

  LocalExpense({
    this.serverId,
    required this.category,
    required this.amount,
    required this.amountBs,
    required this.exchangeRate,
    this.description,
    this.receiptImagePath,
    this.audioPath,
    this.isMultipleTolls,
    this.tollCount,
    required this.createdAt,
    this.synced = false,
    this.syncedAt,
  });
}
