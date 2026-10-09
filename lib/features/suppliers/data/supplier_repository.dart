import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class SupplierWithBalance {
  final Supplier supplier;
  final int balancePaisa; // Total payable bills minus payments made (positive = store owes supplier)
  final int totalPayablePaisa;
  final int totalPaidPaisa;
  final DateTime? lastTransactionDate;

  SupplierWithBalance({
    required this.supplier,
    required this.balancePaisa,
    required this.totalPayablePaisa,
    required this.totalPaidPaisa,
    this.lastTransactionDate,
  });

  bool get owesSupplier => balancePaisa > 0;
  bool get isCleared => balancePaisa <= 0;
}

class SupplierRepository {
  final AppDatabase _db;

  SupplierRepository(this._db);

  Stream<List<SupplierWithBalance>> watchSuppliersWithBalances() {
    return _db.watchSuppliers().asyncMap((suppliers) async {
      final result = <SupplierWithBalance>[];

      for (final s in suppliers) {
        final txs = await _db.getSupplierTransactions(s.id);

        int totalPayable = 0;
        int totalPaid = 0;
        DateTime? lastTxDate;

        for (final tx in txs) {
          if (lastTxDate == null || tx.date.isAfter(lastTxDate)) {
            lastTxDate = tx.date;
          }
          if (tx.type == 'payable') {
            totalPayable += tx.amountPaisa;
          } else if (tx.type == 'payment') {
            totalPaid += tx.amountPaisa;
          }
        }

        final balance = totalPayable - totalPaid;

        result.add(
          SupplierWithBalance(
            supplier: s,
            balancePaisa: balance,
            totalPayablePaisa: totalPayable,
            totalPaidPaisa: totalPaid,
            lastTransactionDate: lastTxDate,
          ),
        );
      }

      return result;
    });
  }

  Future<SupplierWithBalance?> getSupplierWithBalance(int supplierId) async {
    final supplier = await _db.getSupplierById(supplierId);
    if (supplier == null) return null;

    final txs = await _db.getSupplierTransactions(supplierId);
    int totalPayable = 0;
    int totalPaid = 0;
    DateTime? lastTxDate;

    for (final tx in txs) {
      if (lastTxDate == null || tx.date.isAfter(lastTxDate)) {
        lastTxDate = tx.date;
      }
      if (tx.type == 'payable') {
        totalPayable += tx.amountPaisa;
      } else if (tx.type == 'payment') {
        totalPaid += tx.amountPaisa;
      }
    }

    return SupplierWithBalance(
      supplier: supplier,
      balancePaisa: totalPayable - totalPaid,
      totalPayablePaisa: totalPayable,
      totalPaidPaisa: totalPaid,
      lastTransactionDate: lastTxDate,
    );
  }

  Future<List<Supplier>> getAllSuppliers() {
    return _db.getAllSuppliers();
  }

  Future<Supplier?> getSupplierById(int id) {
    return _db.getSupplierById(id);
  }

  Future<int> addSupplier({
    required String name,
    required String phone,
    String? company,
    String? address,
    String? notes,
  }) {
    return _db.insertSupplier(
      SuppliersCompanion(
        name: drift.Value(name),
        phone: drift.Value(phone),
        company: drift.Value(company),
        address: drift.Value(address),
        notes: drift.Value(notes),
      ),
    );
  }

  Future<bool> updateSupplier({
    required int id,
    required String name,
    required String phone,
    String? company,
    String? address,
    String? notes,
  }) {
    return _db.updateSupplier(
      SuppliersCompanion(
        id: drift.Value(id),
        name: drift.Value(name),
        phone: drift.Value(phone),
        company: drift.Value(company),
        address: drift.Value(address),
        notes: drift.Value(notes),
      ),
    );
  }

  Future<int> softDeleteSupplier(int id) {
    return _db.softDeleteSupplier(id);
  }

  Stream<List<SupplierTransaction>> watchSupplierTransactions(int supplierId) {
    return _db.watchSupplierTransactions(supplierId);
  }

  Future<List<SupplierTransaction>> getSupplierTransactions(int supplierId) {
    return _db.getSupplierTransactions(supplierId);
  }

  Future<int> addTransaction({
    required int supplierId,
    required DateTime date,
    required int amountPaisa,
    required String type, // 'payable', 'payment'
    String? reference,
    String? paymentMethod,
    String? otherPaymentMethod,
    String? note,
  }) {
    return _db.recordSupplierTransaction(
      SupplierTransactionsCompanion(
        supplierId: drift.Value(supplierId),
        date: drift.Value(date),
        amountPaisa: drift.Value(amountPaisa),
        type: drift.Value(type),
        reference: drift.Value(reference),
        paymentMethod: drift.Value(paymentMethod),
        otherPaymentMethod: drift.Value(otherPaymentMethod),
        note: drift.Value(note),
      ),
    );
  }

  Future<bool> updateTransaction({
    required int id,
    required int supplierId,
    required DateTime date,
    required int amountPaisa,
    required String type,
    String? reference,
    String? paymentMethod,
    String? otherPaymentMethod,
    String? note,
  }) {
    return _db.updateSupplierTransaction(
      SupplierTransactionsCompanion(
        id: drift.Value(id),
        supplierId: drift.Value(supplierId),
        date: drift.Value(date),
        amountPaisa: drift.Value(amountPaisa),
        type: drift.Value(type),
        reference: drift.Value(reference),
        paymentMethod: drift.Value(paymentMethod),
        otherPaymentMethod: drift.Value(otherPaymentMethod),
        note: drift.Value(note),
      ),
    );
  }

  Future<int> softDeleteTransaction(int id) {
    return _db.softDeleteSupplierTransaction(id);
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SupplierRepository(db);
});

final suppliersWithBalancesStreamProvider = StreamProvider<List<SupplierWithBalance>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.watchSuppliersWithBalances();
});

final supplierTransactionsStreamProvider = StreamProvider.family<List<SupplierTransaction>, int>((ref, supplierId) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.watchSupplierTransactions(supplierId);
});
