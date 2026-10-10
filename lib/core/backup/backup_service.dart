import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../database/connection/connection.dart';
import '../files/attachment_service.dart';

class BackupManifest {
  final String appName;
  final String appVersion;
  final int schemaVersion;
  final String timestamp;
  final int medicineCount;
  final int batchCount;
  final int customerCount;
  final int supplierCount;
  final int saleCount;
  final int expenseCount;
  final int attachmentCount;

  BackupManifest({
    required this.appName,
    required this.appVersion,
    required this.schemaVersion,
    required this.timestamp,
    required this.medicineCount,
    required this.batchCount,
    required this.customerCount,
    required this.supplierCount,
    required this.saleCount,
    required this.expenseCount,
    required this.attachmentCount,
  });

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'timestamp': timestamp,
        'medicineCount': medicineCount,
        'batchCount': batchCount,
        'customerCount': customerCount,
        'supplierCount': supplierCount,
        'saleCount': saleCount,
        'expenseCount': expenseCount,
        'attachmentCount': attachmentCount,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        appName: json['appName'] as String? ?? 'BismillahStore',
        appVersion: json['appVersion'] as String? ?? '1.0.0',
        schemaVersion: json['schemaVersion'] as int? ?? 3,
        timestamp: json['timestamp'] as String? ?? '',
        medicineCount: json['medicineCount'] as int? ?? 0,
        batchCount: json['batchCount'] as int? ?? 0,
        customerCount: json['customerCount'] as int? ?? 0,
        supplierCount: json['supplierCount'] as int? ?? 0,
        saleCount: json['saleCount'] as int? ?? 0,
        expenseCount: json['expenseCount'] as int? ?? 0,
        attachmentCount: json['attachmentCount'] as int? ?? 0,
      );
}

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final BackupManifest? manifest;
  final File? backupFile;

  BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.manifest,
    this.backupFile,
  });
}

class BackupService {
  final AttachmentService _attachmentService = AttachmentService();

  Future<Directory> getBackupsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Creates a complete ZIP backup containing the SQLite database, JSON export, attachments, and manifest.json
  Future<File> createBackup(AppDatabase db) async {
    // 0. Force SQLite WAL checkpoint to flush all pending transactions to disk
    try {
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    // 1. Gather all store records for complete JSON dump and manifest
    final medicines = await db.getAllMedicines();
    final customers = await db.getAllCustomers();
    final customerTxs = await (db.select(db.customerTransactions)..where((tbl) => tbl.isDeleted.equals(false))).get();
    final suppliers = await db.getAllSuppliers();
    final supplierTxs = await (db.select(db.supplierTransactions)..where((tbl) => tbl.isDeleted.equals(false))).get();
    final sales = await (db.select(db.sales)..where((tbl) => tbl.isDeleted.equals(false))).get();
    final expenses = await (db.select(db.expenses)..where((tbl) => tbl.isDeleted.equals(false))).get();
    final attachments = await db.getAllAttachments();
    final settings = await (db.select(db.appSettings)).get();

    final now = DateTime.now();
    final timestampStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final manifest = BackupManifest(
      appName: 'BismillahStore',
      appVersion: '1.0.0',
      schemaVersion: db.schemaVersion,
      timestamp: now.toIso8601String(),
      medicineCount: medicines.length,
      batchCount: medicines.where((m) => m.batchNumber != null && m.batchNumber!.isNotEmpty).length,
      customerCount: customers.length,
      supplierCount: suppliers.length,
      saleCount: sales.length,
      expenseCount: expenses.length,
      attachmentCount: attachments.length,
    );

    // 2. Read SQLite Database File
    final dbFile = await getDatabaseFile();
    if (!await dbFile.exists()) {
      throw Exception('Database file does not exist on disk');
    }
    final dbBytes = await dbFile.readAsBytes();

    // 3. Prepare full JSON data dump
    final storeData = {
      'timestamp': now.toIso8601String(),
      'medicines': medicines.map((m) => m.toJson()).toList(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'customerTransactions': customerTxs.map((t) => t.toJson()).toList(),
      'suppliers': suppliers.map((s) => s.toJson()).toList(),
      'supplierTransactions': supplierTxs.map((t) => t.toJson()).toList(),
      'sales': sales.map((s) => s.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'settings': {for (final s in settings) s.key: s.value},
    };
    final storeDataJson = jsonEncode(storeData);
    final storeDataBytes = utf8.encode(storeDataJson);

    // 4. Prepare ZIP Archive
    final archive = Archive();

    // Add manifest.json
    final manifestJson = jsonEncode(manifest.toJson());
    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    // Add complete structured JSON backup
    archive.addFile(
      ArchiveFile('store_data.json', storeDataBytes.length, storeDataBytes),
    );

    // Add SQLite database file
    archive.addFile(
      ArchiveFile('database.sqlite', dbBytes.length, dbBytes),
    );

    // Add image attachments
    final attachDir = await _attachmentService.getAttachmentsDirectory();
    if (await attachDir.exists()) {
      final files = attachDir.listSync().whereType<File>();
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final fileName = p.basename(f.path);
        archive.addFile(
          ArchiveFile('attachments/$fileName', bytes.length, bytes),
        );
      }
    }

    // 5. Encode ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    final backupDir = await getBackupsDirectory();
    final backupFileName = 'bismillahstore_backup_$timestampStr.zip';
    final backupFile = File(p.join(backupDir.path, backupFileName));
    await backupFile.writeAsBytes(zipData);

    // Copy to Downloads folder on Android for easy access by user
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final targetDownloadFile = File(p.join(downloadDir.path, backupFileName));
        await targetDownloadFile.writeAsBytes(zipData);
      }
    } catch (_) {}

    // Record last backup timestamp in settings
    await db.setSetting('last_backup_timestamp', now.toIso8601String());

    return backupFile;
  }

  Future<String?> copyBackupToDownloads(File backupFile) async {
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final target = File(p.join(downloadDir.path, p.basename(backupFile.path)));
        await backupFile.copy(target.path);
        return target.path;
      }
    } catch (_) {}
    return null;
  }

  /// Validates a chosen backup ZIP file before any restore operation
  Future<BackupValidationResult> validateBackupFile(File file) async {
    try {
      if (!await file.exists()) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'File does not exist.',
        );
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Check manifest
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'Corrupt or invalid backup: Missing manifest.json.',
        );
      }

      final manifestContent = utf8.decode(manifestFile.content as List<int>);
      final manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;
      final manifest = BackupManifest.fromJson(manifestMap);

      // Check database file
      final dbFile = archive.findFile('database.sqlite');
      if (dbFile == null) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'Corrupt or invalid backup: Missing database file.',
        );
      }

      return BackupValidationResult(
        isValid: true,
        manifest: manifest,
        backupFile: file,
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Failed to inspect backup file: ${e.toString()}',
      );
    }
  }

  /// Restores a backup after creating a safety snapshot of current data
  Future<void> restoreBackup(File backupFile, AppDatabase currentDb) async {
    try {
      await createBackup(currentDb);
    } catch (_) {}

    // 1. Force WAL checkpoint to flush all pending operations to disk
    try {
      await currentDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    // 2. Safely close current database connection so all file locks are released
    try {
      await currentDb.close();
    } catch (_) {}

    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbArchiveFile = archive.findFile('database.sqlite');
    if (dbArchiveFile == null) {
      throw Exception('Database file missing in backup package');
    }

    final targetDbFile = await getDatabaseFile();
    final dbFolder = targetDbFile.parent;

    // 3. Remove existing WAL & SHM files so SQLite doesn't replay obsolete WAL journal records
    for (final name in [
      'bismillahstore.sqlite-wal',
      'bismillahstore.sqlite-shm',
      'pharmaledger.sqlite-wal',
      'pharmaledger.sqlite-shm'
    ]) {
      final f = File(p.join(dbFolder.path, name));
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    // 4. Overwrite primary SQLite database file
    final primaryDbFile = File(p.join(dbFolder.path, 'bismillahstore.sqlite'));
    await primaryDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

    // 5. Restore all image and document attachments to managed folder
    final attachDir = await _attachmentService.getAttachmentsDirectory();
    for (final file in archive) {
      if (file.name.startsWith('attachments/') && file.isFile) {
        final fileName = p.basename(file.name);
        if (fileName.isNotEmpty) {
          final targetFile = File(p.join(attachDir.path, fileName));
          await targetFile.writeAsBytes(file.content as List<int>);
        }
      }
    }
  }

  Future<void> shareBackup(File backupFile) async {
    if (await backupFile.exists()) {
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'BismillahStore Data Backup',
      );
    }
  }

  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return null;
    return File(result.files.single.path!);
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
