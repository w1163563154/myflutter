import 'package:sqflite_common/sqlite_api.dart';

String localDatabasePath(String directory, String name) =>
    '${directory.endsWith('/') ? directory.substring(0, directory.length - 1) : directory}/$name';

/// Older Web builds passed //name to the SQLite VFS. URL normalization mapped
/// these names to /, so preserve any tables in that legacy file before opening
/// the correctly named databases. The source is retained unchanged.
Future<Map<String, List<Map<String, Object?>>>> readLegacyTables(
  DatabaseFactory factory,
  String? legacyPath,
  List<String> tables,
) async {
  if (legacyPath == null || !await factory.databaseExists(legacyPath)) {
    return {};
  }
  final source = await factory.openDatabase(
    legacyPath,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
  try {
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      final exists = await source.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ? AND name = ?',
        whereArgs: ['table', table],
      );
      if (exists.isNotEmpty) result[table] = await source.query(table);
    }
    return result;
  } finally {
    await source.close();
  }
}

Future<void> restoreLegacyTables(
  DatabaseExecutor db,
  Map<String, List<Map<String, Object?>>> tables,
) async {
  for (final entry in tables.entries) {
    for (final row in entry.value) {
      await db.insert(entry.key, row);
    }
  }
}
