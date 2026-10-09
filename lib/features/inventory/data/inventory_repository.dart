import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
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

  InventoryRepository(this._db);

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
    bool isDraft = false,
  }) {
    return _db.insertMedicine(
      MedicinesCompanion(
        name: drift.Value(name),
        expiryDate: drift.Value(expiryDate),
        genericName: drift.Value(genericName ?? ''),
        brand: drift.Value(brand ?? ''),
        category: drift.Value(category ?? 'General'),
        notes: drift.Value(notes),
        reminderMonths: drift.Value(reminderMonths),
        isDraft: drift.Value(isDraft),
      ),
    );
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
    bool isDraft = false,
  }) {
    return _db.updateMedicine(
      MedicinesCompanion(
        id: drift.Value(id),
        name: drift.Value(name),
        expiryDate: drift.Value(expiryDate),
        genericName: drift.Value(genericName ?? ''),
        brand: drift.Value(brand ?? ''),
        category: drift.Value(category ?? 'General'),
        notes: drift.Value(notes),
        reminderMonths: drift.Value(reminderMonths),
        isDraft: drift.Value(isDraft),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<int> softDeleteMedicine(int id) {
    return _db.softDeleteMedicine(id);
  }

  Future<int> restoreMedicine(int id) {
    return _db.restoreMedicine(id);
  }

  Future<int> setReminderDisabled(int id, bool isDisabled) {
    return _db.setMedicineReminderStatus(id, isDisabled);
  }

  Future<int> toggleReminderDisabled(int id, bool isDisabled) {
    return _db.setMedicineReminderStatus(id, isDisabled);
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryRepository(db);
});

final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchAllMedicines();
});

final draftMedicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchDraftMedicines();
});
