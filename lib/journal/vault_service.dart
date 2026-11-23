import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'journal_store.dart';

Future<List<int>> _deriveNative((String, List<int>, int) args) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: args.$3,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(args.$1)), nonce: args.$2);
  return key.extractBytes();
}

class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.account,
    required this.password,
    required this.note,
  });
  final int id;
  final String name, url, account, password, note;
}

class VaultService extends ChangeNotifier {
  VaultService(this.store, {this.iterations = 600000});
  static final instance = VaultService(JournalStore.instance);
  final JournalStore store;
  final int iterations;
  final _cipher = AesGcm.with256bits();
  SecretKey? _key;
  int _session = 0;
  Timer? _idle;
  void activity() {
    _idle?.cancel();
    if (isUnlocked) {
      _idle = Timer(const Duration(minutes: 1), lock);
    }
  }

  bool get isUnlocked => _key != null;
  Future<bool> isConfigured() async =>
      (await (await store.database).query('vault_meta')).isNotEmpty;
  Future<SecretKey> _derive(String password, List<int> salt, int rounds) async {
    if (!kIsWeb) {
      return SecretKey(await compute(_deriveNative, (password, salt, rounds)));
    }
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  Future<String> _seal(String text, SecretKey key) async {
    final box = await _cipher.encrypt(utf8.encode(text), secretKey: key);
    return jsonEncode({
      'v': 1,
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> _unseal(String payload, SecretKey key) async {
    final r = jsonDecode(payload) as Map<String, dynamic>;
    if (r['v'] != 1) throw StateError('不支持的密码库版本');
    return utf8.decode(
      await _cipher.decrypt(
        SecretBox(
          base64Decode(r['cipher'] as String),
          nonce: base64Decode(r['nonce'] as String),
          mac: Mac(base64Decode(r['mac'] as String)),
        ),
        secretKey: key,
      ),
    );
  }

  void _check(int session) {
    if (session != _session) throw StateError('密码库已锁定，请重新解锁');
  }

  Future<void> setup(String password) async {
    if (password.runes.length < 12) throw ArgumentError('主密码至少12个字符');
    final session = _session;
    final db = await store.database;
    if (await isConfigured()) throw StateError('密码库已设置');
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final key = await _derive(password, salt, iterations);
    final verifier = await _seal('journal-vault-v1', key);
    _check(session);
    await db.insert('vault_meta', {
      'id': 1,
      'salt': base64Encode(salt),
      'iterations': iterations,
      'verifier': verifier,
    });
    _check(session);
    _key = key;
    activity();
    notifyListeners();
  }

  Future<void> unlock(String password) async {
    final session = _session;
    final rows = await (await store.database).query('vault_meta');
    if (rows.isEmpty) throw StateError('请先设置密码库');
    final row = rows.single;
    final key = await _derive(
      password,
      base64Decode(row['salt'] as String),
      row['iterations'] as int,
    );
    if (await _unseal(row['verifier'] as String, key) != 'journal-vault-v1') {
      throw StateError('密码库校验失败');
    }
    _check(session);
    _key = key;
    activity();
    notifyListeners();
  }

  Future<List<VaultEntry>> entries() async {
    final key = _key;
    if (key == null) throw StateError('请先解锁');
    final session = _session;
    final rows = await (await store.database).query(
      'vault_entries',
      orderBy: 'id DESC',
    );
    final result = <VaultEntry>[];
    for (final row in rows) {
      final r =
          jsonDecode(await _unseal(row['payload'] as String, key))
              as Map<String, dynamic>;
      _check(session);
      result.add(
        VaultEntry(
          id: row['id'] as int,
          name: r['name'] as String,
          url: r['url'] as String,
          account: r['account'] as String,
          password: r['password'] as String,
          note: r['note'] as String,
        ),
      );
    }
    _check(session);
    return result;
  }

  Future<int> save({
    int? id,
    required String name,
    String url = '',
    String account = '',
    required String password,
    String note = '',
  }) async {
    final key = _key;
    if (key == null) throw StateError('请先解锁');
    if (name.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('请填写网站名称和密码');
    }
    final session = _session;
    final payload = await _seal(
      jsonEncode({
        'name': name.trim(),
        'url': url.trim(),
        'account': account,
        'password': password,
        'note': note,
      }),
      key,
    );
    final db = await store.database;
    _check(session);
    if (id == null) return db.insert('vault_entries', {'payload': payload});
    if (await db.update(
          'vault_entries',
          {'payload': payload},
          where: 'id=?',
          whereArgs: [id],
        ) !=
        1) {
      throw StateError('条目不存在');
    }
    return id;
  }

  void lock() {
    _idle?.cancel();
    _session++;
    final key = _key;
    _key = null;
    if (key is SecretKeyData) key.destroy();
    notifyListeners();
  }

  @override
  void dispose() {
    lock();
    super.dispose();
  }
}
