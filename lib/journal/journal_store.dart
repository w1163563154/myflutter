import 'package:sqflite_common/sqlite_api.dart';
import '../records/database_paths.dart';
import '../records/database_native.dart'
    if (dart.library.js_interop) '../records/database_web.dart';

class JournalNote {
  const JournalNote(
    this.id,
    this.title,
    this.body,
    this.updated, {
    this.pinned = false,
  });
  final int id;
  final String title, body;
  final DateTime updated;
  final bool pinned;
  String get displayTitle => title.isEmpty ? body.split('\n').first : title;
}

class JournalStore {
  JournalStore({this.factory, this.path});
  static final instance = JournalStore();
  final DatabaseFactory? factory;
  final String? path;
  static const _pinColumn =
      'pinned INTEGER NOT NULL DEFAULT 0 CHECK(pinned IN (0,1))';
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      final f = factory ?? recordDatabaseFactory;
      final legacy = await readLegacyTables(
        f,
        path == null ? legacyDatabasePath : null,
        ['notes', 'vault_meta', 'vault_entries'],
      );
      return await f.openDatabase(
        path ?? localDatabasePath(await f.getDatabasesPath(), 'journal.db'),
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) {
              await db.execute('ALTER TABLE notes ADD COLUMN $_pinColumn');
            }
          },
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, updated INTEGER NOT NULL, $_pinColumn)',
            );
            await db.execute(
              'CREATE TABLE vault_meta(id INTEGER PRIMARY KEY CHECK(id=1), salt TEXT NOT NULL, iterations INTEGER NOT NULL, verifier TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE vault_entries(id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL)',
            );
            await restoreLegacyTables(db, legacy);
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<List<JournalNote>> notes([String keyword = '']) async {
    final q = keyword.trim();
    final rows = await (await database).query(
      'notes',
      where: 'instr(lower(title),lower(?))>0 OR instr(lower(body),lower(?))>0',
      whereArgs: [q, q],
      orderBy: 'pinned DESC, updated DESC, id DESC',
    );
    return rows
        .map(
          (r) => JournalNote(
            r['id'] as int,
            r['title'] as String,
            r['body'] as String,
            DateTime.fromMillisecondsSinceEpoch(r['updated'] as int),
            pinned: r['pinned'] == 1,
          ),
        )
        .toList();
  }

  Future<int> saveNote({
    int? id,
    required String title,
    required String body,
  }) async {
    if (title.trim().isEmpty && body.trim().isEmpty) {
      throw ArgumentError('请填写标题或正文');
    }
    final row = {
      'title': title.trim(),
      'body': body.trim(),
      'updated': DateTime.now().millisecondsSinceEpoch,
    };
    final db = await database;
    if (id == null) return db.insert('notes', row);
    final count = await db.update('notes', row, where: 'id=?', whereArgs: [id]);
    if (count != 1) throw StateError('笔记不存在');
    return id;
  }

  Future<void> setPinned(int id, bool pinned) async {
    final count = await (await database).update(
      'notes',
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('笔记不存在');
  }

  Future<void> close() async {
    final f = _opening;
    _opening = null;
    if (f != null) await (await f).close();
  }
}
