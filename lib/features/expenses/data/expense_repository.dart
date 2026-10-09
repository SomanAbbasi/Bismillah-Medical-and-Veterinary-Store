import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepository(this._db);

  Stream<List<Expense>> watchExpenses() {
    return _db.watchExpenses();
  }

  Future<List<Expense>> getAllExpenses() {
    return _db.getAllExpenses();
  }

  Future<List<Expense>> getExpensesForRange(DateTime start, DateTime end) {
    return _db.getExpensesBetween(start, end);
  }

  Future<Expense?> getExpenseById(int id) {
    return _db.getExpenseById(id);
  }

  Future<int> addExpense({
    required DateTime date,
    required String title,
    required int amountPaisa,
    String? category,
    String? note,
  }) {
    return _db.insertExpense(
      ExpensesCompanion(
        date: drift.Value(date),
        title: drift.Value(title.trim().isEmpty ? 'Store Expense' : title.trim()),
        amountPaisa: drift.Value(amountPaisa),
        category: drift.Value(category ?? 'General'),
        note: drift.Value(note),
      ),
    );
  }

  Future<bool> updateExpense({
    required int id,
    required DateTime date,
    required String title,
    required int amountPaisa,
    String? category,
    String? note,
  }) {
    return _db.updateExpense(
      ExpensesCompanion(
        id: drift.Value(id),
        date: drift.Value(date),
        title: drift.Value(title.trim().isEmpty ? 'Store Expense' : title.trim()),
        amountPaisa: drift.Value(amountPaisa),
        category: drift.Value(category ?? 'General'),
        note: drift.Value(note),
      ),
    );
  }

  Future<int> softDeleteExpense(int id) {
    return _db.softDeleteExpense(id);
  }

  Future<int> restoreExpense(int id) {
    return _db.restoreExpense(id);
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpenseRepository(db);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchExpenses();
});
