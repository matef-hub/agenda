import 'dart:convert';

import '../database/database_helper.dart';
import '../utils/arabic_format.dart';
import 'secret_vault.dart';

class BackupService {
  final DatabaseHelper database;
  BackupService(this.database);

  Future<String> export(String password) async {
    final db = await database.database;
    final tables = await db.transaction((txn) async {
      final result = <String, dynamic>{};
      for (final table in DatabaseHelper.tables) {
        result[table] = await database.decode(table, await txn.query(table));
      }
      return result;
    });
    return PasswordCipher.encrypt(
      jsonEncode({
        'format': 'judicial-agenda',
        'version': 2,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'tables': tables,
      }),
      password,
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> read(
    String encrypted,
    String password,
  ) async {
    if (encrypted.length > 50 * 1024 * 1024) {
      throw const FormatException('حجم الملف أكبر من المسموح');
    }
    final payload = jsonDecode(
      await PasswordCipher.decrypt(encrypted, password),
    );
    if (payload is! Map ||
        payload['format'] != 'judicial-agenda' ||
        payload['version'] != 2 ||
        payload['tables'] is! Map) {
      throw const FormatException('نسخة غير متوافقة');
    }
    final tables = Map<String, dynamic>.from(payload['tables'] as Map);
    if (tables.length != DatabaseHelper.tables.length ||
        !DatabaseHelper.tables.every(tables.containsKey)) {
      throw const FormatException('النسخة ناقصة');
    }
    final result = <String, List<Map<String, dynamic>>>{};
    final db = await database.database;
    for (final table in DatabaseHelper.tables) {
      final rawRows = tables[table];
      if (rawRows is! List || rawRows.length > 100000) {
        throw const FormatException('جدول غير صالح');
      }
      final schema = await db.rawQuery('PRAGMA table_info($table)');
      final columns = {for (final c in schema) c['name'] as String: c};
      final ids = <int>{};
      final rows = <Map<String, dynamic>>[];
      for (final raw in rawRows) {
        if (raw is! Map) throw const FormatException('سجل غير صالح');
        final row = Map<String, dynamic>.from(raw);
        if (row.length != columns.length ||
            !columns.keys.every(row.containsKey)) {
          throw const FormatException('حقول غير متوافقة');
        }
        for (final entry in columns.entries) {
          final value = row[entry.key];
          if (value == null && entry.value['notnull'] == 1) {
            throw const FormatException('حقل مطلوب مفقود');
          }
          if (value != null &&
              (entry.value['type'] == 'INTEGER'
                  ? value is! int &&
                        !(table == 'sessions' &&
                            entry.key == 'case_year' &&
                            value is String)
                  : value is! String)) {
            throw const FormatException('نوع بيانات غير صالح');
          }
        }
        final id = row['id'];
        if (id is! int || id < 1 || !ids.add(id)) {
          throw const FormatException('رقم سجل غير صالح أو مكرر');
        }
        if (table == 'sessions' &&
            ArabicFormat.parseDate(row['session_date'] as String) == null) {
          throw const FormatException('تاريخ جلسة غير صالح');
        }
        if (table == 'admin_notes' &&
            row['is_completed'] != 0 &&
            row['is_completed'] != 1) {
          throw const FormatException('حالة عمل غير صالحة');
        }
        rows.add(row);
      }
      result[table] = rows;
    }
    return result;
  }

  /// Validate before calling. The transaction makes replacement all-or-nothing.
  Future<void> restore(Map<String, List<Map<String, dynamic>>> tables, {Set<String>? selectedTables}) async {
    if (tables.length != DatabaseHelper.tables.length ||
        !DatabaseHelper.tables.every(tables.containsKey)) {
      throw const FormatException('نسخة ناقصة');
    }
    final selected = selectedTables ?? DatabaseHelper.tables.toSet();
    if (selected.isEmpty || !DatabaseHelper.tables.toSet().containsAll(selected)) {
      throw const FormatException('اختيار الأقسام غير صالح');
    }
    final prepared = <String, List<Map<String, dynamic>>>{};
    for (final table in selected) {
      prepared[table] = [];
      for (final row in tables[table]!) {
        prepared[table]!.add(await database.prepare(table, row));
      }
    }
    final db = await database.database;
    await db.transaction((txn) async {
      for (final table in selected) {
        await txn.delete(table);
        for (final row in prepared[table]!) {
          await txn.insert(table, row);
        }
      }
    });
  }
}
