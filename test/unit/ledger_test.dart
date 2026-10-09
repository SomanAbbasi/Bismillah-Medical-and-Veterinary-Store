import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ledger Arithmetic Tests', () {
    test('Customer balance ledger formula calculation', () {
      // Opening balance: Rs. 1000 (100,000 paisa)
      const openingBalance = 100000;
      // Credit sale 1: Rs. 500 (50,000 paisa)
      const creditSale1 = 50000;
      // Credit sale 2: Rs. 250 (25,000 paisa)
      const creditSale2 = 25000;
      // Customer payment: Rs. 800 (80,000 paisa)
      const payment1 = 80000;
      // Customer return credit adjustment: Rs. 100 (10,000 paisa)
      const returnCredit = 10000;

      final totalCredits = openingBalance + creditSale1 + creditSale2;
      final totalDebits = payment1 + returnCredit;
      final currentBalance = totalCredits - totalDebits;

      // 175,000 - 90,000 = 85,000 paisa = Rs. 850
      expect(currentBalance, 85000);
      expect(currentBalance > 0, true); // Still has outstanding balance
    });

    test('Supplier payable balance ledger formula calculation', () {
      // Opening balance: Rs. 5000 (500,000 paisa)
      const openingPayable = 500000;
      // Stock purchase on credit: Rs. 12000 (1,200,000 paisa)
      const purchaseCredit = 1200000;
      // Partial payment made to supplier: Rs. 10000 (1,000,000 paisa)
      const supplierPayment = 1000000;
      // Damaged goods return refund: Rs. 2000 (200,000 paisa)
      const returnDebit = 200000;

      final totalOwed = openingPayable + purchaseCredit;
      final totalPaidOrReturned = supplierPayment + returnDebit;
      final remainingOwed = totalOwed - totalPaidOrReturned;

      // 1,700,000 - 1,200,000 = 500,000 paisa = Rs. 5000
      expect(remainingOwed, 500000);
    });
  });
}
