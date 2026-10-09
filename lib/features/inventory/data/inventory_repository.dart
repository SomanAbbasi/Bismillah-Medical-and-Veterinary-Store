import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/expiry_reminder_scheduler.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';

class MedicineExpiryStatus {
  final Medicine medicine;

  MedicineExpiryStatus(this.medicine);

  ExpiryStatus get status => ExpiryUtils.getStatus(medicine.expiryDate);
  int get daysRemaining => ExpiryUtils.getDaysRemaining(medicine.expiryDate);
  String get humanRemaining => ExpiryUtils.getHumanRemainingText(medicine.expiryDate);
  bool get isExpired => medicine.expiryDate.isBefore(DateFormatter.today());
}

class InventoryRepository {
  final AppDatabase _db;
  final ExpiryReminderScheduler? _scheduler;

  InventoryRepository(this._db, [this._scheduler]);

  Stream<List<Medicine>> watchAllMedicines({bool includeDrafts = false}) {
    return _db.watchAllMedicines(includeDrafts: includeDrafts);
  }

  Stream<List<Medicine>> watchDraftMedicines() {
    return _db.watchDraftMedicines();
  }

  Future<List<Medicine>> getAllMedicines() {
    return _db.getAllMedicines();
  }

  Future<Medicine?> getMedicineById(int medicineId) {
    return _db.getMedicineById(medicineId);
  }

  Future<int> addMedicine({
    required String name,
    required DateTime expiryDate,
    String? genericName,
    String? brand,
    String? category,
    String? notes,
    int? reminderMonths,
    int? reminderLeadDays,
    int? reminderIntervalMinutes,
    bool isDraft = false,
  }) async {
    final id = await _db.insertMedicine(
      MedicinesCompanion(
        name: drift.Value(name),
        expiryDate: drift.Value(expiryDate),
        genericName: drift.Value(genericName ?? ''),
        brand: drift.Value(brand ?? ''),
        category: drift.Value(category ?? 'General'),
        notes: drift.Value(notes),
        reminderMonths: drift.Value(reminderMonths),
        reminderLeadDays: drift.Value(reminderLeadDays),
        reminderIntervalMinutes: drift.Value(reminderIntervalMinutes),
        isDraft: drift.Value(isDraft),
      ),
    );

    await _scheduler?.reconcile(_db);
    return id;
  }

  Future<bool> updateMedicine({
    required int id,
    required String name,
    required DateTime expiryDate,
    String? genericName,
    String? brand,
    String? category,
    String? notes,
    int? reminderMonths,
    int? reminderLeadDays,
    int? reminderIntervalMinutes,
    bool isDraft = false,
  }) async {
    final res = await _db.updateMedicine(
      MedicinesCompanion(
        id: drift.Value(id),
        name: drift.Value(name),
        expiryDate: drift.Value(expiryDate),
        genericName: drift.Value(genericName ?? ''),
        brand: drift.Value(brand ?? ''),
        category: drift.Value(category ?? 'General'),
        notes: drift.Value(notes),
        reminderMonths: drift.Value(reminderMonths),
        reminderLeadDays: drift.Value(reminderLeadDays),
        reminderIntervalMinutes: drift.Value(reminderIntervalMinutes),
        isDraft: drift.Value(isDraft),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    await _scheduler?.reconcile(_db);
    return res;
  }

  Future<int> softDeleteMedicine(int id) async {
    final res = await _db.softDeleteMedicine(id);
    await _scheduler?.reconcile(_db);
    return res;
  }

  Future<int> restoreMedicine(int id) async {
    final res = await _db.restoreMedicine(id);
    await _scheduler?.reconcile(_db);
    return res;
  }

  Future<int> setReminderDisabled(int id, bool isDisabled) async {
    final res = await _db.setMedicineReminderStatus(id, isDisabled);
    await _scheduler?.reconcile(_db);
    return res;
  }

  Future<int> toggleReminderDisabled(int id, bool isDisabled) async {
    return setReminderDisabled(id, isDisabled);
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final scheduler = ref.watch(expiryReminderSchedulerProvider);
  return InventoryRepository(db, scheduler);
});

final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchAllMedicines();
});

final draftMedicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchDraftMedicines();
});
