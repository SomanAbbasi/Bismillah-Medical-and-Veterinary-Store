import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arslan_medical_store/core/database/app_database.dart';
import 'package:arslan_medical_store/core/database/schema_reconciler.dart';
import 'package:arslan_medical_store/core/widgets/app_error_widget.dart';

void main() {
  group('Database Schema Migration & Self-Healing Reconciler Tests', () {
    test('Self-healing reconciler automatically adds missing is_deleted column to legacy sales table without data loss', () async {
      // 1. Create an in-memory database simulating a legacy APK installation
      // where the "sales" table was created without "is_deleted" and "deleted_at" columns.
      final executor = NativeDatabase.memory();

      // Open raw connection to execute legacy schema
      final rawDb = AppDatabase(executor);
      await rawDb.customStatement('DROP TABLE IF EXISTS sales;');
      await rawDb.customStatement('''
        CREATE TABLE sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date INTEGER NOT NULL,
          title TEXT NOT NULL DEFAULT 'Store Sale',
          customer_id INTEGER,
          total_amount_paisa INTEGER NOT NULL,
          discount_paisa INTEGER NOT NULL DEFAULT 0,
          final_amount_paisa INTEGER NOT NULL,
          payment_type TEXT NOT NULL DEFAULT 'cash',
          cash_paid_paisa INTEGER NOT NULL DEFAULT 0,
          credit_amount_paisa INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
      ''');

      // Insert legacy sale record
      await rawDb.customStatement('''
        INSERT INTO sales (date, title, total_amount_paisa, discount_paisa, final_amount_paisa)
        VALUES (1700000000000, 'Panadol Box Sale', 15000, 0, 15000);
      ''');

      // Verify that "is_deleted" does NOT exist initially
      final initialCols = await SchemaReconciler.getTableColumns(rawDb, 'sales');
      expect(initialCols.contains('is_deleted'), false);

      // 2. Run SchemaReconciler.reconcile(rawDb)
      await SchemaReconciler.reconcile(rawDb);

      // Verify that "is_deleted" and "deleted_at" now exist
      final updatedCols = await SchemaReconciler.getTableColumns(rawDb, 'sales');
      expect(updatedCols.contains('is_deleted'), true);
      expect(updatedCols.contains('deleted_at'), true);

      // 3. Verify that existing sale record was preserved with is_deleted = 0
      final sales = await rawDb.getAllSales();
      expect(sales.length, 1);
      expect(sales.first.title, 'Panadol Box Sale');
      expect(sales.first.finalAmountPaisa, 15000);
      expect(sales.first.isDeleted, false);

      await rawDb.close();
    });

    test('Self-healing reconciler creates missing tables and reconciles all 10 core tables safely', () async {
      final executor = NativeDatabase.memory();
      final db = AppDatabase(executor);

      // Run reconciler on empty database
      await SchemaReconciler.reconcile(db);

      // Verify all tables exist and have is_deleted where required
      final expectedTables = [
        'medicines',
        'customers',
        'customer_transactions',
        'suppliers',
        'supplier_transactions',
        'sales',
        'expenses',
        'attachments',
        'in_app_notifications',
        'app_settings',
      ];

      for (final table in expectedTables) {
        final cols = await SchemaReconciler.getTableColumns(db, table);
        expect(cols.isNotEmpty, true, reason: 'Table $table must have columns');

        if (table != 'in_app_notifications' && table != 'app_settings') {
          expect(cols.contains('is_deleted'), true, reason: 'Table $table must have is_deleted');
        }
      }

      await db.close();
    });
  });

  group('AppErrorFormatter User-Facing Error Sanitization Tests', () {
    test('Hides raw SQLite exceptions and SQL queries from end users', () {
      const rawError = 'SqliteException(1): while preparing statement, no such column: "is_deleted" ... SELECT * FROM "sales" WHERE ("is_deleted" = ? AND "date" >= ?) AND "date" <= ? ORDER BY "date" DESC;';

      final userMessage = AppErrorFormatter.toUserFriendlyMessage(rawError);

      expect(userMessage.contains('SqliteException'), false);
      expect(userMessage.contains('SELECT'), false);
      expect(userMessage.contains('is_deleted'), false);
      expect(userMessage, contains('local database sync issue'));
    });

    test('Sanitizes storage and filesystem errors into clear permissions guidance', () {
      const rawError = 'FileSystemException: Cannot open file, path = /data/user/0/com.bismillah.store/app_flutter/test.jpg (OS Error: Permission denied, errno = 13)';

      final userMessage = AppErrorFormatter.toUserFriendlyMessage(rawError);

      expect(userMessage.contains('/data/user/0'), false);
      expect(userMessage.contains('errno = 13'), false);
      expect(userMessage, contains('permissions'));
    });

    test('Sanitizes network socket exceptions into simple connection message', () {
      const rawError = 'SocketException: Failed host lookup: google.com (OS Error: No address associated with hostname)';

      final userMessage = AppErrorFormatter.toUserFriendlyMessage(rawError);

      expect(userMessage.contains('SocketException'), false);
      expect(userMessage, contains('internet connection'));
    });

    test('Default fallback provides actionable retry message without technical jargon', () {
      const rawError = 'RangeError (index): Invalid value: Valid value range is empty: 0';

      final userMessage = AppErrorFormatter.toUserFriendlyMessage(rawError);

      expect(userMessage.contains('RangeError'), false);
      expect(userMessage, contains('Tap Retry to reload'));
    });
  });
}
