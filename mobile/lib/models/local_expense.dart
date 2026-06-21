import 'package:isar/isar.dart';

part 'local_expense.g.dart';

@collection
class LocalExpense {
  Id id = Isar.autoIncrement;

  @Index()
  String? serverId;

  String category; // peaje | hotel | gasolina | otros
  double amount;
  double? amountBs;
  double? exchangeRate;
  String? description;
  String? receiptImagePath;

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
    this.amountBs,
    this.exchangeRate,
    this.description,
    this.receiptImagePath,
    this.isMultipleTolls,
    this.tollCount,
    required this.createdAt,
    this.synced = false,
    this.syncedAt,
  });
}
