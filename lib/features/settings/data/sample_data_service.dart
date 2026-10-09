import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';

class SampleDataService {
  static Future<bool> populateSampleData(AppDatabase db) async {
    try {
      // 1. Add Medicines
      await db.insertMedicine(
        MedicinesCompanion(
          name: const drift.Value('Panadol 500mg'),
          genericName: const drift.Value('Paracetamol'),
          brand: const drift.Value('GSK Pakistan'),
          category: const drift.Value('Analgesic / Antipyretic'),
          expiryDate: drift.Value(DateTime.now().add(const Duration(days: 365))),
          reminderMonths: const drift.Value(3),
        ),
      );

      await db.insertMedicine(
        MedicinesCompanion(
          name: const drift.Value('Augmentin 625mg'),
          genericName: const drift.Value('Amoxicillin + Clavulanic Acid'),
          brand: const drift.Value('GSK'),
          category: const drift.Value('Antibiotic'),
          expiryDate: drift.Value(DateTime.now().add(const Duration(days: 45))), // Expiring soon
          reminderMonths: const drift.Value(3),
        ),
      );

      await db.insertMedicine(
        MedicinesCompanion(
          name: const drift.Value('Brufen 400mg'),
          genericName: const drift.Value('Ibuprofen'),
          brand: const drift.Value('Abbott'),
          category: const drift.Value('NSAID / Pain Relief'),
          expiryDate: drift.Value(DateTime.now().subtract(const Duration(days: 10))), // Expired
          reminderMonths: const drift.Value(2),
        ),
      );

      // 2. Add Customers
      final aliKhanId = await db.insertCustomer(
        CustomersCompanion(
          name: const drift.Value('Ali Khan'),
          phone: const drift.Value('0300-5544332'),
          address: const drift.Value('House 44, Street 9, Near Jamia Masjid'),
          notes: const drift.Value('Regular neighborhood customer'),
        ),
      );

      await db.insertCustomer(
        CustomersCompanion(
          name: const drift.Value('Dr. Usman Tariq'),
          phone: const drift.Value('0345-1234567'),
          address: const drift.Value('Clinic #2, Main Bazaar'),
        ),
      );

      // 3. Add Customer Transactions
      await db.recordCustomerTransaction(
        CustomerTransactionsCompanion(
          customerId: drift.Value(aliKhanId),
          date: drift.Value(DateTime.now().subtract(const Duration(days: 5))),
          amountPaisa: const drift.Value(500000), // Rs. 5,000
          type: const drift.Value('credit'),
          reference: const drift.Value('Slip #101'),
          note: const drift.Value('Monthly diabetes & blood pressure medicines'),
        ),
      );

      await db.recordCustomerTransaction(
        CustomerTransactionsCompanion(
          customerId: drift.Value(aliKhanId),
          date: drift.Value(DateTime.now().subtract(const Duration(days: 1))),
          amountPaisa: const drift.Value(150000), // Rs. 1,500
          type: const drift.Value('payment'),
          paymentMethod: const drift.Value('Cash'),
          reference: const drift.Value('Receipt #204'),
          note: const drift.Value('Cash payment received'),
        ),
      );

      // 4. Add Sales for Today
      await db.insertSale(
        SalesCompanion(
          date: drift.Value(DateTime.now()),
          title: const drift.Value('Morning Counter Sale'),
          finalAmountPaisa: const drift.Value(250000), // Rs. 2,500
          paymentType: const drift.Value('cash'),
          notes: const drift.Value('General counter sales'),
        ),
      );

      // 5. Add Expenses
      await db.insertExpense(
        ExpensesCompanion(
          date: drift.Value(DateTime.now()),
          title: const drift.Value('SEPCO Electricity Bill'),
          amountPaisa: const drift.Value(450000), // Rs. 4,500
          category: const drift.Value('Electricity'),
          note: const drift.Value('Store AC & lighting daily share'),
        ),
      );

      await db.insertExpense(
        ExpensesCompanion(
          date: drift.Value(DateTime.now()),
          title: const drift.Value('Tea & Refreshments'),
          amountPaisa: const drift.Value(30000), // Rs. 300
          category: const drift.Value('Tea'),
          note: const drift.Value('Shop guests tea bill'),
        ),
      );

      return true;
    } catch (_) {
      return false;
    }
  }
}
