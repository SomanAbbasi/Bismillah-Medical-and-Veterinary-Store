import 'package:flutter/foundation.dart';
import 'app_database.dart';

/// Ensures that the SQLite database has all required tables and columns,
/// self-healing any schema mismatch caused by older APK builds or restored backups.
///
/// This runs non-destructively: existing tables and rows are never dropped or modified,
/// and added columns use safe default values so existing records remain intact.
class SchemaReconciler {
  /// Runs complete schema inspection and reconciles missing tables and columns.
  static Future<void> reconcile(AppDatabase db) async {
    try {
      // 1. Enforce foreign key constraints
      try {
        await db.customStatement('PRAGMA foreign_keys = ON;');
      } catch (e) {
        debugPrint('[SchemaReconciler] Notice setting foreign_keys: $e');
      }

      // 2. Ensure all core tables exist (safe IF NOT EXISTS)
      await _ensureTables(db);

      // 3. Reconcile missing columns across all tables
      await _ensureMedicinesColumns(db);
      await _ensureCustomersColumns(db);
      await _ensureCustomerTransactionsColumns(db);
      await _ensureSuppliersColumns(db);
      await _ensureSupplierTransactionsColumns(db);
      await _ensureSalesColumns(db);
      await _ensureExpensesColumns(db);
      await _ensureAttachmentsColumns(db);
      await _ensureInAppNotificationsColumns(db);
      await _ensureAppSettingsColumns(db);

      debugPrint('[SchemaReconciler] Schema verified and reconciled successfully.');
    } catch (e, stack) {
      debugPrint('[SchemaReconciler] Error during schema reconciliation: $e\n$stack');
    }
  }

  /// Retrieves lowercase column names for a given table.
  static Future<Set<String>> getTableColumns(AppDatabase db, String tableName) async {
    try {
      final rows = await db.customSelect('PRAGMA table_info("$tableName");').get();
      return rows.map((r) => r.read<String>('name').toLowerCase()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Safely adds a column to a table if it does not already exist.
  static Future<void> ensureColumn(
    AppDatabase db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    try {
      final existingColumns = await getTableColumns(db, tableName);
      if (!existingColumns.contains(columnName.toLowerCase())) {
        await db.customStatement(
          'ALTER TABLE "$tableName" ADD COLUMN "$columnName" $columnDefinition;',
        );
        debugPrint('[SchemaReconciler] Added column "$columnName" to table "$tableName".');
      }
    } catch (e) {
      debugPrint('[SchemaReconciler] Notice adding column $columnName to $tableName: $e');
    }
  }

  // ==================== TABLE CREATION ====================

  static Future<void> _ensureTables(AppDatabase db) async {
    // 1. medicines
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS medicines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        batch_number TEXT,
        generic_name TEXT NOT NULL DEFAULT '',
        brand TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'General',
        expiry_date INTEGER NOT NULL,
        notes TEXT,
        reminder_months INTEGER,
        reminder_lead_days INTEGER,
        reminder_interval_minutes INTEGER,
        preferred_hour INTEGER NOT NULL DEFAULT 9,
        preferred_minute INTEGER NOT NULL DEFAULT 0,
        notification_id INTEGER,
        last_scheduled_at INTEGER,
        next_scheduled_at INTEGER,
        is_reminder_disabled INTEGER NOT NULL DEFAULT 0,
        is_draft INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 2. customers
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        alternative_phone TEXT,
        address TEXT,
        notes TEXT,
        photo_path TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 3. customer_transactions
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS customer_transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers (id),
        date INTEGER NOT NULL,
        amount_paisa INTEGER NOT NULL,
        type TEXT NOT NULL,
        reference TEXT,
        payment_method TEXT,
        other_payment_method TEXT,
        note TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 4. suppliers
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        company TEXT,
        address TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 5. supplier_transactions
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS supplier_transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL REFERENCES suppliers (id),
        date INTEGER NOT NULL,
        amount_paisa INTEGER NOT NULL,
        type TEXT NOT NULL,
        reference TEXT,
        payment_method TEXT,
        other_payment_method TEXT,
        note TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 6. sales
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT 'Store Sale',
        customer_id INTEGER REFERENCES customers (id),
        total_amount_paisa INTEGER NOT NULL,
        discount_paisa INTEGER NOT NULL DEFAULT 0,
        final_amount_paisa INTEGER NOT NULL,
        payment_type TEXT NOT NULL DEFAULT 'cash',
        cash_paid_paisa INTEGER NOT NULL DEFAULT 0,
        credit_amount_paisa INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 7. expenses
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        amount_paisa INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT 'Store Expense',
        category TEXT,
        note TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 8. attachments
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
        description TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );
    ''');

    // 9. in_app_notifications
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS in_app_notifications (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT NOT NULL,
        related_entity_type TEXT,
        related_entity_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_resolved INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
    ''');

    // 10. app_settings
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  // ==================== COLUMN RECONCILIATION ====================

  static Future<void> _ensureSalesColumns(AppDatabase db) async {
    await ensureColumn(db, 'sales', 'title', "TEXT NOT NULL DEFAULT 'Store Sale'");
    await ensureColumn(db, 'sales', 'customer_id', 'INTEGER');
    await ensureColumn(db, 'sales', 'discount_paisa', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'sales', 'payment_type', "TEXT NOT NULL DEFAULT 'cash'");
    await ensureColumn(db, 'sales', 'cash_paid_paisa', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'sales', 'credit_amount_paisa', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'sales', 'notes', 'TEXT');
    await ensureColumn(db, 'sales', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'sales', 'updated_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'sales', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'sales', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureExpensesColumns(AppDatabase db) async {
    await ensureColumn(db, 'expenses', 'title', "TEXT NOT NULL DEFAULT 'Store Expense'");
    await ensureColumn(db, 'expenses', 'category', 'TEXT');
    await ensureColumn(db, 'expenses', 'note', 'TEXT');
    await ensureColumn(db, 'expenses', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'expenses', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'expenses', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureMedicinesColumns(AppDatabase db) async {
    await ensureColumn(db, 'medicines', 'batch_number', 'TEXT');
    await ensureColumn(db, 'medicines', 'generic_name', "TEXT NOT NULL DEFAULT ''");
    await ensureColumn(db, 'medicines', 'brand', "TEXT NOT NULL DEFAULT ''");
    await ensureColumn(db, 'medicines', 'category', "TEXT NOT NULL DEFAULT 'General'");
    await ensureColumn(db, 'medicines', 'notes', 'TEXT');
    await ensureColumn(db, 'medicines', 'reminder_months', 'INTEGER');
    await ensureColumn(db, 'medicines', 'reminder_lead_days', 'INTEGER');
    await ensureColumn(db, 'medicines', 'reminder_interval_minutes', 'INTEGER');
    await ensureColumn(db, 'medicines', 'preferred_hour', 'INTEGER NOT NULL DEFAULT 9');
    await ensureColumn(db, 'medicines', 'preferred_minute', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'medicines', 'notification_id', 'INTEGER');
    await ensureColumn(db, 'medicines', 'last_scheduled_at', 'INTEGER');
    await ensureColumn(db, 'medicines', 'next_scheduled_at', 'INTEGER');
    await ensureColumn(db, 'medicines', 'is_reminder_disabled', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'medicines', 'is_draft', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'medicines', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'medicines', 'updated_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'medicines', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'medicines', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureCustomersColumns(AppDatabase db) async {
    await ensureColumn(db, 'customers', 'phone', "TEXT NOT NULL DEFAULT ''");
    await ensureColumn(db, 'customers', 'alternative_phone', 'TEXT');
    await ensureColumn(db, 'customers', 'address', 'TEXT');
    await ensureColumn(db, 'customers', 'notes', 'TEXT');
    await ensureColumn(db, 'customers', 'photo_path', 'TEXT');
    await ensureColumn(db, 'customers', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'customers', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'customers', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureCustomerTransactionsColumns(AppDatabase db) async {
    await ensureColumn(db, 'customer_transactions', 'reference', 'TEXT');
    await ensureColumn(db, 'customer_transactions', 'payment_method', 'TEXT');
    await ensureColumn(db, 'customer_transactions', 'other_payment_method', 'TEXT');
    await ensureColumn(db, 'customer_transactions', 'note', 'TEXT');
    await ensureColumn(db, 'customer_transactions', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'customer_transactions', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'customer_transactions', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureSuppliersColumns(AppDatabase db) async {
    await ensureColumn(db, 'suppliers', 'phone', "TEXT NOT NULL DEFAULT ''");
    await ensureColumn(db, 'suppliers', 'company', 'TEXT');
    await ensureColumn(db, 'suppliers', 'address', 'TEXT');
    await ensureColumn(db, 'suppliers', 'notes', 'TEXT');
    await ensureColumn(db, 'suppliers', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'suppliers', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'suppliers', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureSupplierTransactionsColumns(AppDatabase db) async {
    await ensureColumn(db, 'supplier_transactions', 'reference', 'TEXT');
    await ensureColumn(db, 'supplier_transactions', 'payment_method', 'TEXT');
    await ensureColumn(db, 'supplier_transactions', 'other_payment_method', 'TEXT');
    await ensureColumn(db, 'supplier_transactions', 'note', 'TEXT');
    await ensureColumn(db, 'supplier_transactions', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'supplier_transactions', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'supplier_transactions', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureAttachmentsColumns(AppDatabase db) async {
    await ensureColumn(db, 'attachments', 'mime_type', "TEXT NOT NULL DEFAULT 'image/jpeg'");
    await ensureColumn(db, 'attachments', 'description', 'TEXT');
    await ensureColumn(db, 'attachments', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
    await ensureColumn(db, 'attachments', 'is_deleted', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'attachments', 'deleted_at', 'INTEGER');
  }

  static Future<void> _ensureInAppNotificationsColumns(AppDatabase db) async {
    await ensureColumn(db, 'in_app_notifications', 'related_entity_type', 'TEXT');
    await ensureColumn(db, 'in_app_notifications', 'related_entity_id', 'INTEGER');
    await ensureColumn(db, 'in_app_notifications', 'is_read', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'in_app_notifications', 'is_resolved', 'INTEGER NOT NULL DEFAULT 0');
    await ensureColumn(db, 'in_app_notifications', 'created_at', "INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))");
  }

  static Future<void> _ensureAppSettingsColumns(AppDatabase db) async {
    await ensureColumn(db, 'app_settings', 'value', "TEXT NOT NULL DEFAULT ''");
  }
}
