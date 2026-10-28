import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupReminder {
  static const _storage = FlutterSecureStorage();
  static const _key = 'agenda_last_backup_v1';
  static const interval = Duration(days: 7);

  static Future<DateTime?> lastSaved() async {
    final value = await _storage.read(key: _key);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  static Future<void> recordSaved(DateTime date) =>
      _storage.write(key: _key, value: date.toUtc().toIso8601String());

  static bool due(DateTime? lastSaved, DateTime now) =>
      lastSaved == null || now.difference(lastSaved) >= interval;
}
