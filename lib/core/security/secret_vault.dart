import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecretVault {
  static const _storage = FlutterSecureStorage();
  static final _cipher = AesGcm.with256bits();
  static Future<SecretKey>? _pendingKey;
  static const sensitive = {
    'id_card_no',
    'passport_no',
    'bank_account_no',
    'credit_card_no',
  };
  static Future<SecretKey> _key() => _pendingKey ??= _loadKey();
  static Future<SecretKey> _loadKey() async {
    try {
      var encoded = await _storage.read(key: 'agenda_field_key_v1');
      if (encoded == null) {
        final key = await _cipher.newSecretKey();
        encoded = base64Encode(await key.extractBytes());
        await _storage.write(key: 'agenda_field_key_v1', value: encoded);
      }
      return SecretKey(base64Decode(encoded));
    } catch (_) {
      _pendingKey = null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> protect(Map<String, dynamic> row) async {
    final result = Map<String, dynamic>.from(row);
    for (final field in sensitive) {
      final value = result[field];
      if (value is String && value.isNotEmpty) {
        final box = await _cipher.encrypt(
          utf8.encode(value),
          secretKey: await _key(),
        );
        result[field] = 'enc:v1:${base64Encode(box.concatenation())}';
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> reveal(Map<String, dynamic> row) async {
    final result = Map<String, dynamic>.from(row);
    for (final field in sensitive) {
      final value = result[field];
      if (value is String && value.startsWith('enc:v1:')) {
        final box = SecretBox.fromConcatenation(
          base64Decode(value.substring(7)),
          nonceLength: 12,
          macLength: 16,
        );
        result[field] = utf8.decode(
          await _cipher.decrypt(box, secretKey: await _key()),
        );
      }
    }
    return result;
  }

  static Future<void> migrate(
    DatabaseWriter writer,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      if (sensitive.any(
        (field) =>
            row[field] is String &&
            (row[field] as String).isNotEmpty &&
            !(row[field] as String).startsWith('enc:v1:'),
      )) {
        // Reveal first so already encrypted columns are not encrypted twice.
        await writer(await protect(await reveal(row)));
      }
    }
  }
}

typedef DatabaseWriter = Future<void> Function(Map<String, dynamic> row);

class PasswordCipher {
  static final _cipher = AesGcm.with256bits();
  static Future<SecretKey> _derive(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  static Future<String> encrypt(String text, String password) async {
    if (password.length < 10)
      throw const FormatException('استخدم كلمة مرور من عشرة أحرف على الأقل');
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final box = await _cipher.encrypt(
      utf8.encode(text),
      secretKey: await _derive(password, salt),
    );
    return jsonEncode({
      'format': 'agenda-encrypted',
      'version': 1,
      'salt': base64Encode(salt),
      'data': base64Encode(box.concatenation()),
    });
  }

  static Future<String> decrypt(String text, String password) async {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['format'] != 'agenda-encrypted' || json['version'] != 1) {
      throw const FormatException('صيغة النسخة الاحتياطية غير مدعومة');
    }
    final salt = base64Decode(json['salt'] as String);
    final data = base64Decode(json['data'] as String);
    if (salt.length != 16 || data.length < 28)
      throw const FormatException('ملف غير صالح');
    final box = SecretBox.fromConcatenation(
      data,
      nonceLength: 12,
      macLength: 16,
    );
    return utf8.decode(
      await _cipher.decrypt(box, secretKey: await _derive(password, salt)),
    );
  }

  static Future<bool> hasLock() async =>
      await SecretVault._storage.read(key: 'agenda_lock_v1') != null;
  static Future<void> setLock(String password) async =>
      SecretVault._storage.write(
        key: 'agenda_lock_v1',
        value: await encrypt('agenda-unlock', password),
      );
  static Future<bool> unlock(String password) async {
    final value = await SecretVault._storage.read(key: 'agenda_lock_v1');
    if (value == null) return true;
    try {
      return await decrypt(value, password) == 'agenda-unlock';
    } catch (_) {
      return false;
    }
  }

  static Future<void> removeLock(String password) async {
    if (!await unlock(password))
      throw const FormatException('كلمة المرور غير صحيحة');
    await SecretVault._storage.delete(key: 'agenda_lock_v1');
  }
}
