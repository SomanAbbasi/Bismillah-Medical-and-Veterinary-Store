import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class SupplierWithBalance {
  final int id;
  final String name;
  final String phone;
  final int balanceOwedPaisa;

  SupplierWithBalance({
    required this.id,
    required this.name,
    required this.phone,
    required this.balanceOwedPaisa,
  });

  bool get hasPayable => balanceOwedPaisa > 0;
}

class SupplierRepository {
  final AppDatabase _db;

  SupplierRepository(this._db);

  Stream<List<SupplierWithBalance>> watchSuppliersWithBalances() {
    return Stream.value([]);
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SupplierRepository(db);
});

final suppliersWithBalancesStreamProvider = StreamProvider<List<SupplierWithBalance>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.watchSuppliersWithBalances();
});
