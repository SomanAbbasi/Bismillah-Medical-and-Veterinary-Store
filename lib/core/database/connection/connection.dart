import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

LazyDatabase openConnection({String dbName = 'bismillahstore.sqlite'}) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    var file = File(p.join(dbFolder.path, dbName));
    if (!await file.exists()) {
      final oldFile = File(p.join(dbFolder.path, 'pharmaledger.sqlite'));
      if (await oldFile.exists()) {
        try {
          await oldFile.copy(file.path);
        } catch (_) {
          file = oldFile;
        }
      }
    }
    return NativeDatabase.createInBackground(file);
  });
}

Future<File> getDatabaseFile({String dbName = 'bismillahstore.sqlite'}) async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, dbName));
  if (!await file.exists()) {
    final oldFile = File(p.join(dbFolder.path, 'pharmaledger.sqlite'));
    if (await oldFile.exists()) return oldFile;
  }
  return file;
}
