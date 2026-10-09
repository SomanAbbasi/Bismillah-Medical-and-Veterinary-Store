import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../../expenses/data/expense_repository.dart';

class DashboardSummary {
  final int todaySalesPaisa;
  final int todayExpensesPaisa;
  final int todayNetPaisa;
  final int customerOutstandingPaisa;
  final int supplierOutstandingPaisa;
  final int expiredMedicinesCount;
  final int expiringSoonMedicinesCount;
  final List<Medicine> topExpiringMedicines;
  final List<CustomerWithBalance> topOverdueCustomers;

  DashboardSummary({
    required this.todaySalesPaisa,
    required this.todayExpensesPaisa,
    required this.todayNetPaisa,
    required this.customerOutstandingPaisa,
    required this.supplierOutstandingPaisa,
    required this.expiredMedicinesCount,
    required this.expiringSoonMedicinesCount,
    required this.topExpiringMedicines,
    required this.topOverdueCustomers,
  });
}

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final todayStart = DateFormatter.today();
  final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

  final salesRepo = ref.watch(salesRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final supplierRepo = ref.watch(supplierRepositoryProvider);
  final inventoryRepo = ref.watch(inventoryRepositoryProvider);
  final db = ref.watch(databaseProvider);

  final defaultReminderSetting = await db.getSetting('default_reminder_months');
  final globalDefaultMonths = defaultReminderSetting != null ? (int.tryParse(defaultReminderSetting) ?? 1) : 1;

  // Sales today
  final sales = await salesRepo.getSalesForRange(todayStart, todayEnd);
  final todaySalesPaisa = sales.fold(0, (sum, s) => sum + s.finalAmountPaisa);

  // Expenses today
  final expenses = await expenseRepo.getExpensesForRange(todayStart, todayEnd);
  final todayExpensesPaisa = expenses.fold(0, (sum, e) => sum + e.amountPaisa);

  // Today Net
  final todayNetPaisa = todaySalesPaisa - todayExpensesPaisa;

  // Customers Udhaar
  final customers = await customerRepo.watchCustomersWithBalances().first;
  final customerOutstandingPaisa = customers
      .where((c) => c.balancePaisa > 0)
      .fold(0, (sum, c) => sum + c.balancePaisa);

  final overdueCustomers = customers.where((c) => c.balancePaisa > 0).toList()
    ..sort((a, b) => b.balancePaisa.compareTo(a.balancePaisa));

  // Supplier Udhaar (Payables)
  final suppliers = await supplierRepo.watchSuppliersWithBalances().first;
  final supplierOutstandingPaisa = suppliers
      .where((s) => s.balancePaisa > 0)
      .fold(0, (sum, s) => sum + s.balancePaisa);

  // Medicines & Expiry
  final medicines = await inventoryRepo.getAllMedicines();

  int expiredCount = 0;
  int expiringSoonCount = 0;
  final List<Medicine> expiringList = [];

  for (final m in medicines) {
    if (m.isDraft) continue;

    final isExpired = m.expiryDate.isBefore(todayStart);
    final thresholdMonths = m.reminderMonths ?? globalDefaultMonths;
    final isExpiringSoon = ExpiryUtils.isInReminderWindow(m.expiryDate, thresholdMonths, referenceDate: todayStart);

    if (isExpired) {
      expiredCount++;
      expiringList.add(m);
    } else if (isExpiringSoon) {
      expiringSoonCount++;
      expiringList.add(m);
    }
  }

  expiringList.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  return DashboardSummary(
    todaySalesPaisa: todaySalesPaisa,
    todayExpensesPaisa: todayExpensesPaisa,
    todayNetPaisa: todayNetPaisa,
    customerOutstandingPaisa: customerOutstandingPaisa,
    supplierOutstandingPaisa: supplierOutstandingPaisa,
    expiredMedicinesCount: expiredCount,
    expiringSoonMedicinesCount: expiringSoonCount,
    topExpiringMedicines: expiringList,
    topOverdueCustomers: overdueCustomers,
  );
});
