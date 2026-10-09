import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class CustomerWithBalance {
  final Customer customer;
  final int balancePaisa; // Positive means customer owes store
  final DateTime? lastTransactionDate;

  CustomerWithBalance({
    required this.customer,
    required this.balancePaisa,
    this.lastTransactionDate,
  });

  bool get owesMoney => balancePaisa > 0;
}

class CustomerTransactionWithRunningBalance {
  final CustomerTransaction transaction;
  final int runningBalancePaisa;

  CustomerTransactionWithRunningBalance({
    required this.transaction,
    required this.runningBalancePaisa,
  });
}

class CustomerRepository {
  final AppDatabase _db;

  CustomerRepository(this._db);

  Stream<List<CustomerWithBalance>> watchCustomersWithBalances() {
    return _db.watchCustomers().asyncMap((customers) async {
      final List<CustomerWithBalance> result = [];
      for (final cust in customers) {
        final txs = await _db.getCustomerTransactions(cust.id);
        int balance = 0;
        DateTime? lastDate;

        for (final tx in txs) {
          if (tx.type == 'credit' || tx.type == 'adjustment_debit') {
            balance += tx.amountPaisa;
          } else if (tx.type == 'payment' || tx.type == 'adjustment_credit') {
            balance -= tx.amountPaisa;
          }
          lastDate = tx.date;
        }

        result.add(CustomerWithBalance(
          customer: cust,
          balancePaisa: balance,
          lastTransactionDate: lastDate,
        ));
      }
      return result;
    });
  }

  Future<int> getCustomerBalance(int customerId) async {
    final txs = await _db.getCustomerTransactions(customerId);
    int balance = 0;
    for (final tx in txs) {
      if (tx.type == 'credit' || tx.type == 'adjustment_debit') {
        balance += tx.amountPaisa;
      } else if (tx.type == 'payment' || tx.type == 'adjustment_credit') {
        balance -= tx.amountPaisa;
      }
    }
    return balance;
  }

  Future<List<CustomerTransactionWithRunningBalance>> getTransactionsWithRunningBalance(
    int customerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var txs = await _db.getCustomerTransactions(customerId);
    if (startDate != null) {
      txs = txs.where((t) => !t.date.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      txs = txs.where((t) => !t.date.isAfter(endDate)).toList();
    }

    final List<CustomerTransactionWithRunningBalance> result = [];
    int running = 0;

    for (final tx in txs) {
      if (tx.type == 'credit' || tx.type == 'adjustment_debit') {
        running += tx.amountPaisa;
      } else if (tx.type == 'payment' || tx.type == 'adjustment_credit') {
        running -= tx.amountPaisa;
      }
      result.add(CustomerTransactionWithRunningBalance(
        transaction: tx,
        runningBalancePaisa: running,
      ));
    }

    return result;
  }

  Future<Customer?> getCustomerById(int id) {
    return _db.getCustomerById(id);
  }

  Future<int> addCustomer(CustomersCompanion customer) {
    return _db.insertCustomer(customer);
  }

  Future<bool> updateCustomer(CustomersCompanion customer) {
    return _db.updateCustomer(customer);
  }

  Future<int> softDeleteCustomer(int id) {
    return _db.softDeleteCustomer(id);
  }

  Future<int> restoreCustomer(int id) {
    return _db.restoreCustomer(id);
  }

  Future<int> addCredit({
    required int customerId,
    required int amountPaisa,
    required DateTime date,
    String? note,
    String? reference,
  }) {
    return _db.recordCustomerTransaction(
      CustomerTransactionsCompanion(
        customerId: drift.Value(customerId),
        date: drift.Value(date),
        amountPaisa: drift.Value(amountPaisa),
        type: const drift.Value('credit'),
        note: drift.Value(note),
        reference: drift.Value(reference),
      ),
    );
  }

  Future<int> recordPayment({
    required int customerId,
    required int amountPaisa,
    required DateTime date,
    String? paymentMethod,
    String? otherPaymentMethod,
    String? note,
    String? reference,
  }) {
    return _db.recordCustomerTransaction(
      CustomerTransactionsCompanion(
        customerId: drift.Value(customerId),
        date: drift.Value(date),
        amountPaisa: drift.Value(amountPaisa),
        type: const drift.Value('payment'),
        paymentMethod: drift.Value(paymentMethod ?? 'Cash'),
        otherPaymentMethod: drift.Value(otherPaymentMethod),
        note: drift.Value(note),
        reference: drift.Value(reference),
      ),
    );
  }

  Future<bool> updateTransaction({
    required int id,
    required int customerId,
    required DateTime date,
    required int amountPaisa,
    required String type,
    String? paymentMethod,
    String? otherPaymentMethod,
    String? note,
    String? reference,
  }) {
    return _db.updateCustomerTransaction(
      CustomerTransactionsCompanion(
        id: drift.Value(id),
        customerId: drift.Value(customerId),
        date: drift.Value(date),
        amountPaisa: drift.Value(amountPaisa),
        type: drift.Value(type),
        paymentMethod: drift.Value(paymentMethod),
        otherPaymentMethod: drift.Value(otherPaymentMethod),
        note: drift.Value(note),
        reference: drift.Value(reference),
      ),
    );
  }

  Future<int> softDeleteTransaction(int id) {
    return _db.softDeleteCustomerTransaction(id);
  }

  Future<int> restoreTransaction(int id) {
    return _db.restoreCustomerTransaction(id);
  }

  /// Exact requested WhatsApp Credit Message Format
  String generateWhatsAppCreditMessage({
    required String shopName,
    required String customerName,
    required int creditAmountPaisa,
    required int previousBalancePaisa,
    required int newBalancePaisa,
  }) {
    final storeName = shopName.isNotEmpty ? shopName : 'Bismillah Medical and Veterinary Store';
    final amtStr = CurrencyFormatter.formatPaisa(creditAmountPaisa);
    final prevStr = CurrencyFormatter.formatPaisa(previousBalancePaisa);
    final newStr = CurrencyFormatter.formatPaisa(newBalancePaisa);

    return 'Assalam-o-Alaikum $customerName,\n\n'
        'A credit entry of $amtStr has been recorded at $storeName.\n\n'
        'Previous balance: $prevStr\n\n'
        'New balance: $newStr\n\n'
        'Please contact us if you have any questions.';
  }

  /// Exact requested WhatsApp Payment Received Message Format
  String generateWhatsAppPaymentMessage({
    required String shopName,
    required String customerName,
    required int paymentAmountPaisa,
    required int previousBalancePaisa,
    required int remainingBalancePaisa,
  }) {
    final amtStr = CurrencyFormatter.formatPaisa(paymentAmountPaisa);
    final prevStr = CurrencyFormatter.formatPaisa(previousBalancePaisa);
    final remStr = CurrencyFormatter.formatPaisa(remainingBalancePaisa);

    return 'Assalam-o-Alaikum $customerName,\n\n'
        'We have received your payment of $amtStr.\n\n'
        'Previous balance: $prevStr\n\n'
        'Payment received: $amtStr\n\n'
        'Remaining balance: $remStr\n\n'
        'Thank you for your payment.';
  }

  String generateStatementText({
    required String shopName,
    required Customer customer,
    required List<CustomerTransactionWithRunningBalance> history,
    required int currentBalancePaisa,
  }) {
    final buffer = StringBuffer();
    final effectiveShop = shopName.isNotEmpty ? shopName : 'Bismillah Medical and Veterinary Store';
    buffer.writeln('*$effectiveShop*');
    buffer.writeln('*Customer Account Statement*');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Customer: ${customer.name}');
    if (customer.phone.isNotEmpty) {
      buffer.writeln('Phone: ${customer.phone}');
    }
    buffer.writeln('Date: ${DateFormatter.formatDate(DateTime.now())}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Transactions:');

    if (history.isEmpty) {
      buffer.writeln('No transaction history recorded.');
    } else {
      final recent = history.length > 10 ? history.sublist(history.length - 10) : history;
      for (final item in recent) {
        final dateStr = DateFormatter.formatDate(item.transaction.date);
        final isCredit = item.transaction.type == 'credit' || item.transaction.type == 'adjustment_debit';
        final typeStr = isCredit ? 'Credit' : 'Payment';
        final sign = isCredit ? '+' : '-';
        final amtStr = CurrencyFormatter.formatPaisa(item.transaction.amountPaisa);
        final noteStr = item.transaction.note != null && item.transaction.note!.isNotEmpty
            ? ' (${item.transaction.note})'
            : '';
        buffer.writeln('• $dateStr: $typeStr $sign$amtStr$noteStr');
      }
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('Current Balance: ${CurrencyFormatter.formatPaisa(currentBalancePaisa)}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Thank you!');
    return buffer.toString();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CustomerRepository(db);
});

final customersWithBalancesStreamProvider = StreamProvider<List<CustomerWithBalance>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.watchCustomersWithBalances();
});
