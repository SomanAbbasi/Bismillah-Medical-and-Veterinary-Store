import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class SupplierTransactionWithRunningBalance {
  final SupplierTransaction transaction;
  final int runningBalancePaisa;

  SupplierTransactionWithRunningBalance({
    required this.transaction,
    required this.runningBalancePaisa,
  });
}

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
    final query = _db.select(_db.suppliers)..where((tbl) => tbl.isDeleted.equals(false));
    final joined = query.join([
      drift.leftOuterJoin(
        _db.supplierTransactions,
        _db.supplierTransactions.supplierId.equalsExp(_db.suppliers.id) &
        _db.supplierTransactions.isDeleted.equals(false),
      ),
    ]);

    return joined.watch().map((rows) {
      final Map<int, Supplier> supplierMap = {};
      final Map<int, int> payableMap = {};
      final Map<int, int> paidMap = {};
      final Map<int, DateTime> lastDateMap = {};

      for (final row in rows) {
        final supplier = row.readTable(_db.suppliers);
        final tx = row.readTableOrNull(_db.supplierTransactions);

        supplierMap[supplier.id] = supplier;
        payableMap.putIfAbsent(supplier.id, () => 0);
        paidMap.putIfAbsent(supplier.id, () => 0);

        if (tx != null) {
          if (tx.type == 'payable') {
            payableMap[supplier.id] = payableMap[supplier.id]! + tx.amountPaisa;
          } else if (tx.type == 'payment') {
            paidMap[supplier.id] = paidMap[supplier.id]! + tx.amountPaisa;
          }

          final currentLast = lastDateMap[supplier.id];
          if (currentLast == null || tx.date.isAfter(currentLast)) {
            lastDateMap[supplier.id] = tx.date;
          }
        }
      }

      return supplierMap.values.map((s) {
        final totalPayable = payableMap[s.id] ?? 0;
        final totalPaid = paidMap[s.id] ?? 0;
        return SupplierWithBalance(
          supplier: s,
          balancePaisa: totalPayable - totalPaid,
          totalPayablePaisa: totalPayable,
          totalPaidPaisa: totalPaid,
          lastTransactionDate: lastDateMap[s.id],
        );
      }).toList();
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

  Future<int> getSupplierBalancePaisa(int supplierId) async {
    final swb = await getSupplierWithBalance(supplierId);
    return swb?.balancePaisa ?? 0;
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

  Future<int> restoreTransaction(int id) {
    return _db.restoreSupplierTransaction(id);
  }

  Future<List<SupplierTransactionWithRunningBalance>> getTransactionsWithRunningBalance(
    int supplierId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var txs = await _db.getSupplierTransactions(supplierId);
    if (startDate != null) {
      txs = txs.where((t) => !t.date.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      txs = txs.where((t) => !t.date.isAfter(endDate)).toList();
    }

    final List<SupplierTransactionWithRunningBalance> result = [];
    int running = 0;

    for (final tx in txs) {
      if (tx.type == 'payable') {
        running += tx.amountPaisa;
      } else if (tx.type == 'payment') {
        running -= tx.amountPaisa;
      }
      result.add(SupplierTransactionWithRunningBalance(
        transaction: tx,
        runningBalancePaisa: running,
      ));
    }

    return result;
  }

  String generateStatementText({
    required String shopName,
    required Supplier supplier,
    required List<SupplierTransactionWithRunningBalance> history,
    required int currentBalancePaisa,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('===================================');
    buffer.writeln(shopName);
    buffer.writeln('SUPPLIER ACCOUNT STATEMENT');
    buffer.writeln('===================================');
    buffer.writeln('Supplier: ${supplier.name}');
    if (supplier.phone.isNotEmpty) buffer.writeln('Phone: ${supplier.phone}');
    if (supplier.company != null && supplier.company!.isNotEmpty) {
      buffer.writeln('Company: ${supplier.company}');
    }
    buffer.writeln('Date: ${DateFormatter.formatDate(DateTime.now())}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Date       | Type    | Amount   | Balance');
    buffer.writeln('-----------------------------------');

    for (final item in history) {
      final t = item.transaction;
      final dateStr = DateFormatter.formatShortDate(t.date);
      final isPayable = t.type == 'payable';
      final typeStr = isPayable ? 'Bill(+)' : 'Paid(-)';
      final amtStr = CurrencyFormatter.formatPaisa(t.amountPaisa);
      final balStr = CurrencyFormatter.formatPaisa(item.runningBalancePaisa);
      buffer.writeln('$dateStr | $typeStr | $amtStr | $balStr');
      if (t.reference != null && t.reference!.isNotEmpty) {
        buffer.writeln('   Ref: ${t.reference}');
      }
      if (t.note != null && t.note!.isNotEmpty) {
        buffer.writeln('   Note: ${t.note}');
      }
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('Current Balance: ${CurrencyFormatter.formatPaisa(currentBalancePaisa)}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Thank you!');
    return buffer.toString();
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
