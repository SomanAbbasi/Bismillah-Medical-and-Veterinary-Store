import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class SaleWithCustomer {
  final Sale sale;
  final Customer? customer;

  SaleWithCustomer({required this.sale, this.customer});
}

class SalesRepository {
  final AppDatabase _db;

  SalesRepository(this._db);

  Stream<List<Sale>> watchRecentSales() {
    return _db.watchSales();
  }

  Future<List<Sale>> getAllSales() {
    return _db.getAllSales();
  }

  Future<List<Sale>> getSalesForRange(DateTime start, DateTime end) {
    return _db.getSalesBetween(start, end);
  }

  Future<SaleWithCustomer?> getSaleDetails(int saleId) async {
    final sale = await _db.getSaleById(saleId);
    if (sale == null) return null;

    Customer? customer;
    if (sale.customerId != null) {
      customer = await _db.getCustomerById(sale.customerId!);
    }

    return SaleWithCustomer(sale: sale, customer: customer);
  }

  Future<int> createSale({
    required DateTime date,
    required String title,
    required int amountPaisa,
    required String paymentType, // 'cash' or 'credit'
    int? customerId,
    String? notes,
  }) {
    final isCredit = paymentType == 'credit';
    return _db.createSale(
      SalesCompanion(
        date: drift.Value(date),
        title: drift.Value(title.trim().isEmpty ? 'Store Sale' : title.trim()),
        customerId: drift.Value(customerId),
        totalAmountPaisa: drift.Value(amountPaisa),
        discountPaisa: const drift.Value(0),
        finalAmountPaisa: drift.Value(amountPaisa),
        paymentType: drift.Value(paymentType),
        cashPaidPaisa: drift.Value(isCredit ? 0 : amountPaisa),
        creditAmountPaisa: drift.Value(isCredit ? amountPaisa : 0),
        notes: drift.Value(notes),
      ),
    );
  }

  Future<bool> updateSale({
    required int id,
    required DateTime date,
    required String title,
    required int amountPaisa,
    required String paymentType,
    int? customerId,
    String? notes,
  }) {
    final isCredit = paymentType == 'credit';
    return _db.updateSale(
      SalesCompanion(
        id: drift.Value(id),
        date: drift.Value(date),
        title: drift.Value(title.trim().isEmpty ? 'Store Sale' : title.trim()),
        customerId: drift.Value(customerId),
        totalAmountPaisa: drift.Value(amountPaisa),
        discountPaisa: const drift.Value(0),
        finalAmountPaisa: drift.Value(amountPaisa),
        paymentType: drift.Value(paymentType),
        cashPaidPaisa: drift.Value(isCredit ? 0 : amountPaisa),
        creditAmountPaisa: drift.Value(isCredit ? amountPaisa : 0),
        notes: drift.Value(notes),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<int> softDeleteSale(int id) {
    return _db.softDeleteSale(id);
  }

  Future<int> restoreSale(int id) {
    return _db.restoreSale(id);
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SalesRepository(db);
});

final recentSalesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return repo.watchRecentSales();
});
