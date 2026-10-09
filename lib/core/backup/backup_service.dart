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
        appName: json['appName'] as String? ?? 'Bismillah Medical and Veterinary Store',
        appVersion: json['appVersion'] as String? ?? '1.0.0',
        schemaVersion: json['schemaVersion'] as int? ?? 2,
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

  /// Creates a complete ZIP backup containing the SQLite database, attachments, and manifest.json
  Future<File> createBackup(AppDatabase db) async {
    // 1. Gather record statistics for manifest
    final medicines = await db.getAllMedicines();
    final customers = await db.getAllCustomers();
    final sales = await db.select(db.sales).get();
    final expenses = await db.select(db.expenses).get();
    final attachments = await db.getAllAttachments();

    final now = DateTime.now();
    final timestampStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final manifest = BackupManifest(
      appName: 'Bismillah Medical and Veterinary Store',
      appVersion: '1.0.0',
      schemaVersion: db.schemaVersion,
      timestamp: now.toIso8601String(),
      medicineCount: medicines.length,
      batchCount: 0,
      customerCount: customers.length,
      supplierCount: 0,
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

    // 3. Prepare ZIP Archive
    final archive = Archive();

    // Add manifest.json
    final manifestJson = jsonEncode(manifest.toJson());
    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    // Add database file
    archive.addFile(
      ArchiveFile('database.sqlite', dbBytes.length, dbBytes),
    );

    // Add attachments
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

    // 4. Encode ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    final backupDir = await getBackupsDirectory();
    final backupFileName = 'bismillah_store_backup_$timestampStr.zip';
    final backupFile = File(p.join(backupDir.path, backupFileName));
    await backupFile.writeAsBytes(zipData);

    // Record last backup timestamp in settings
    await db.setSetting('last_backup_timestamp', now.toIso8601String());

    return backupFile;
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

    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbArchiveFile = archive.findFile('database.sqlite');
    if (dbArchiveFile == null) {
      throw Exception('Database file missing in backup package');
    }

    final targetDbFile = await getDatabaseFile();
    await targetDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

    final attachDir = await _attachmentService.getAttachmentsDirectory();
    for (final file in archive) {
      if (file.name.startsWith('attachments/') && !file.isFile) continue;
      if (file.name.startsWith('attachments/')) {
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
        text: 'Bismillah Store Data Backup',
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
