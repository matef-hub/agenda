import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'arabic_format.dart';

/// Retrieves Calendarific holidays using the key supplied when building.
class HolidaySync extends ChangeNotifier {
  static const configuredKey = String.fromEnvironment(
    'CALENDARIFIC_API_KEY',
  );
  static final instance = HolidaySync();
  static const _storage = FlutterSecureStorage();
  final http.Client _client;
  final String apiKey;
  final Map<int, Future<HolidaySnapshot?>> _pending = {};
  final Map<int, (DateTime, HolidaySnapshot?)> _recent = {};

  HolidaySync({http.Client? client, this.apiKey = configuredKey})
    : _client = client ?? http.Client();

  Future<HolidaySnapshot?> forYear(int year) {
    final recent = _recent[year];
    if (recent != null &&
        DateTime.now().difference(recent.$1) < const Duration(hours: 1)) {
      return Future.value(recent.$2);
    }
    return _pending.putIfAbsent(year, () async {
      try {
        final value = await _load(year);
        _recent[year] = (DateTime.now(), value);
        return value;
      } finally {
        _pending.remove(year);
      }
    });
  }

  Future<HolidaySnapshot?> _load(int year) async {
    if (year < 1900 || year > 2200) return null;
    final cacheKey = 'agenda_holidays_${year}_v1';
    HolidaySnapshot? cached;
    try {
      final data = await _storage.read(key: cacheKey);
      if (data != null) cached = HolidaySnapshot.fromCache(data, year);
    } catch (_) {
      // A storage failure must not prevent opening the agenda.
    }
    if (apiKey.trim().isEmpty) {
      return cached;
    }
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(hours: 24)) {
      return cached;
    }
    try {
      final uri = Uri.https('calendarific.com', '/api/v2/holidays', {
        'api_key': apiKey.trim(),
        'country': 'EG',
        'year': '$year',
        'type': 'national',
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 1024 * 1024) {
        return cached;
      }
      final snapshot = HolidaySnapshot.fromResponse(
        response.body,
        year,
        DateTime.now(),
      );
      if (snapshot == null) return cached;
      try {
        await _storage.write(key: cacheKey, value: snapshot.toCache());
      } catch (_) {
        // Use the successful response even if it could not be cached.
      }
      return snapshot;
    } catch (_) {
      return cached;
    }
  }
}

class HolidaySnapshot {
  final DateTime fetchedAt;
  final Map<String, String> holidays;
  const HolidaySnapshot(this.fetchedAt, this.holidays);

  static HolidaySnapshot? fromResponse(
    String body,
    int year,
    DateTime fetchedAt,
  ) {
    try {
      final json = jsonDecode(body);
      if (json is! Map ||
          json['meta'] is! Map ||
          json['meta']['code'] != 200 ||
          json['response'] is! Map ||
          json['response']['holidays'] is! List) {
        return null;
      }
      final rows = json['response']['holidays'] as List;
      if (rows.isEmpty || rows.length > 500) return null;
      final dates = <String, String>{};
      for (final row in rows) {
        if (row is! Map ||
            row['date'] is! Map ||
            row['date']['iso'] is! String ||
            row['name'] is! String) {
          return null;
        }
        final iso = (row['date']['iso'] as String);
        final name = (row['name'] as String).trim();
        if (iso.length < 10 || name.isEmpty || name.length > 200) return null;
        final key = iso.substring(0, 10);
        final date = DateTime.tryParse(key);
        if (date == null ||
            ArabicFormat.dateKey(date) != key ||
            date.year != year) {
          return null;
        }
        dates.putIfAbsent(key, () => name);
      }
      return HolidaySnapshot(fetchedAt, dates);
    } catch (_) {
      return null;
    }
  }

  String toCache() => jsonEncode({
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'holidays': holidays,
  });

  static HolidaySnapshot? fromCache(String raw, int year) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['fetchedAt'] is! String ||
          data['holidays'] is! Map) {
        return null;
      }
      final date = DateTime.tryParse(data['fetchedAt'] as String);
      if (date == null) return null;
      final holidays = <String, String>{};
      for (final entry in (data['holidays'] as Map).entries) {
        if (entry.key is! String || entry.value is! String) return null;
        final day = DateTime.tryParse(entry.key as String);
        if (day == null ||
            day.year != year ||
            ArabicFormat.dateKey(day) != entry.key ||
            (entry.value as String).trim().isEmpty ||
            (entry.value as String).length > 200) {
          return null;
        }
        holidays[entry.key as String] = entry.value as String;
      }
      if (holidays.isEmpty || holidays.length > 500) return null;
      return HolidaySnapshot(date.toLocal(), holidays);
    } catch (_) {
      return null;
    }
  }
}
