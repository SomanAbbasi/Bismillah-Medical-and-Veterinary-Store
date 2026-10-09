import 'package:drift/drift.dart';
import 'tables.dart';
import 'connection/connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Medicines,
  Customers,
  CustomerTransactions,
  Sales,
  Expenses,
  Attachments,
  InAppNotifications,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Re-create all tables for schema v2
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
        await m.createTable(table);
      }
    },
  );

  // ==================== APP SETTINGS QUERIES ====================

  Future<String?> getSetting(String key) async {
    final query = select(appSettings)..where((tbl) => tbl.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  // ==================== MEDICINES & EXPIRY ====================

  Future<List<Medicine>> getAllMedicines({bool includeDeleted = false, bool draftsOnly = false}) {
    final query = select(medicines);
    if (!includeDeleted) {
      query.where((tbl) => tbl.isDeleted.equals(false));
    }
    if (draftsOnly) {
      query.where((tbl) => tbl.isDraft.equals(true));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.expiryDate, mode: OrderingMode.asc)]);
    return query.get();
  }

  Stream<List<Medicine>> watchAllMedicines({bool includeDrafts = false}) {
    final query = select(medicines)..where((tbl) => tbl.isDeleted.equals(false));
    if (!includeDrafts) {
      query.where((tbl) => tbl.isDraft.equals(false));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.expiryDate, mode: OrderingMode.asc)]);
    return query.watch();
  }

  Stream<List<Medicine>> watchDraftMedicines() {
    return (select(medicines)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.isDraft.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<Medicine?> getMedicineById(int id) {
    return (select(medicines)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertMedicine(MedicinesCompanion entry) {
    return into(medicines).insert(entry);
  }

  Future<bool> updateMedicine(MedicinesCompanion entry) {
    return update(medicines).replace(entry);
  }

  Future<int> softDeleteMedicine(int id) {
    return (update(medicines)..where((tbl) => tbl.id.equals(id))).write(
      MedicinesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreMedicine(int id) {
    return (update(medicines)..where((tbl) => tbl.id.equals(id))).write(
      const MedicinesCompanion(
        isDeleted: Value(false),
        deletedAt: Value.absent(),
      ),
    );
  }

  Future<int> setMedicineReminderStatus(int id, bool isDisabled) {
    return (update(medicines)..where((tbl) => tbl.id.equals(id))).write(
      MedicinesCompanion(isReminderDisabled: Value(isDisabled)),
    );
  }

  // ==================== CUSTOMERS & LEDGER ====================

  Stream<List<Customer>> watchCustomers() {
    return (select(customers)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<Customer>> getAllCustomers() {
    return (select(customers)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc)]))
        .get();
  }

  Future<Customer?> getCustomerById(int id) {
    return (select(customers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCustomer(CustomersCompanion entry) {
    return into(customers).insert(entry);
  }

  Future<bool> updateCustomer(CustomersCompanion entry) {
    return update(customers).replace(entry);
  }

  Future<int> softDeleteCustomer(int id) {
    return (update(customers)..where((tbl) => tbl.id.equals(id))).write(
      CustomersCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreCustomer(int id) {
    return (update(customers)..where((tbl) => tbl.id.equals(id))).write(
      const CustomersCompanion(
        isDeleted: Value(false),
        deletedAt: Value.absent(),
      ),
    );
  }

  Stream<List<CustomerTransaction>> watchCustomerTransactions(int customerId) {
    return (select(customerTransactions)
          ..where((tbl) => tbl.customerId.equals(customerId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<CustomerTransaction>> getCustomerTransactions(int customerId) {
    return (select(customerTransactions)
          ..where((tbl) => tbl.customerId.equals(customerId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.asc)]))
        .get();
  }

  Future<CustomerTransaction?> getCustomerTransactionById(int id) {
    return (select(customerTransactions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> recordCustomerTransaction(CustomerTransactionsCompanion entry) {
    return into(customerTransactions).insert(entry);
  }

  Future<bool> updateCustomerTransaction(CustomerTransactionsCompanion entry) {
    return update(customerTransactions).replace(entry);
  }

  Future<int> softDeleteCustomerTransaction(int id) {
    return (update(customerTransactions)..where((tbl) => tbl.id.equals(id))).write(
      CustomerTransactionsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreCustomerTransaction(int id) {
    return (update(customerTransactions)..where((tbl) => tbl.id.equals(id))).write(
      const CustomerTransactionsCompanion(
        isDeleted: Value(false),
        deletedAt: Value.absent(),
      ),
    );
  }

  // ==================== SALES (FULL CRUD & ATOMIC LEDGER) ====================

  Stream<List<Sale>> watchSales() {
    return (select(sales)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Sale>> getAllSales() {
    return (select(sales)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<Sale>> getSalesBetween(DateTime start, DateTime end) {
    return (select(sales)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.date.isBiggerOrEqualValue(start) & tbl.date.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .get();
  }

  Future<Sale?> getSaleById(int id) {
    return (select(sales)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Atomic transaction for creating a sale + customer credit ledger entry if applicable
  Future<int> createSale(SalesCompanion saleEntry) {
    return transaction(() async {
      final saleId = await into(sales).insert(saleEntry);

      final creditAmount = saleEntry.creditAmountPaisa.value;
      final customerId = saleEntry.customerId.value;
      if (creditAmount > 0 && customerId != null) {
        await into(customerTransactions).insert(
          CustomerTransactionsCompanion(
            customerId: Value(customerId),
            date: saleEntry.date,
            amountPaisa: Value(creditAmount),
            type: const Value('credit'),
            reference: Value('Sale #$saleId'),
            note: Value(saleEntry.notes.value ?? saleEntry.title.value),
          ),
        );
      }

      return saleId;
    });
  }

  Future<bool> updateSale(SalesCompanion saleEntry) {
    return update(sales).replace(saleEntry);
  }

  Future<int> softDeleteSale(int id) {
    return (update(sales)..where((tbl) => tbl.id.equals(id))).write(
      SalesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreSale(int id) {
    return (update(sales)..where((tbl) => tbl.id.equals(id))).write(
      const SalesCompanion(
        isDeleted: Value(false),
        deletedAt: Value.absent(),
      ),
    );
  }

  // ==================== EXPENSES (FULL CRUD) ====================

  Stream<List<Expense>> watchExpenses() {
    return (select(expenses)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Expense>> getAllExpenses() {
    return (select(expenses)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<Expense>> getExpensesBetween(DateTime start, DateTime end) {
    return (select(expenses)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.date.isBiggerOrEqualValue(start) & tbl.date.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .get();
  }

  Future<Expense?> getExpenseById(int id) {
    return (select(expenses)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertExpense(ExpensesCompanion entry) {
    return into(expenses).insert(entry);
  }

  Future<bool> updateExpense(ExpensesCompanion entry) {
    return update(expenses).replace(entry);
  }

  Future<int> softDeleteExpense(int id) {
    return (update(expenses)..where((tbl) => tbl.id.equals(id))).write(
      ExpensesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreExpense(int id) {
    return (update(expenses)..where((tbl) => tbl.id.equals(id))).write(
      const ExpensesCompanion(
        isDeleted: Value(false),
        deletedAt: Value.absent(),
      ),
    );
  }

  // ==================== MULTIPLE ATTACHMENTS ====================

  Stream<List<Attachment>> watchAttachments(String entityType, int entityId) {
    return (select(attachments)
          ..where((tbl) => tbl.entityType.equals(entityType) & tbl.entityId.equals(entityId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Attachment>> getAttachments(String entityType, int entityId) {
    return (select(attachments)
          ..where((tbl) => tbl.entityType.equals(entityType) & tbl.entityId.equals(entityId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<Attachment>> getAllAttachments() {
    return (select(attachments)..where((tbl) => tbl.isDeleted.equals(false))).get();
  }

  Future<int> insertAttachment(AttachmentsCompanion entry) {
    return into(attachments).insert(entry);
  }

  Future<int> deleteAttachment(int id) {
    return (delete(attachments)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== RECYCLE BIN / 30-DAY TRASH & AUTO PURGE ====================

  /// Auto purges items soft-deleted more than 30 days ago
  Future<void> purgeOldDeletedItems() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    await transaction(() async {
      await (delete(medicines)..where((tbl) => tbl.isDeleted.equals(true) & tbl.deletedAt.isSmallerOrEqualValue(cutoffDate))).go();
      await (delete(sales)..where((tbl) => tbl.isDeleted.equals(true) & tbl.deletedAt.isSmallerOrEqualValue(cutoffDate))).go();
      await (delete(expenses)..where((tbl) => tbl.isDeleted.equals(true) & tbl.deletedAt.isSmallerOrEqualValue(cutoffDate))).go();
      await (delete(customerTransactions)..where((tbl) => tbl.isDeleted.equals(true) & tbl.deletedAt.isSmallerOrEqualValue(cutoffDate))).go();
      await (delete(customers)..where((tbl) => tbl.isDeleted.equals(true) & tbl.deletedAt.isSmallerOrEqualValue(cutoffDate))).go();
    });
  }

  Future<void> clearAllData() {
    return transaction(() async {
      await delete(sales).go();
      await delete(customerTransactions).go();
      await delete(medicines).go();
      await delete(customers).go();
      await delete(expenses).go();
      await delete(attachments).go();
      await delete(inAppNotifications).go();
    });
  }
}
