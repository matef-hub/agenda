import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'arabic_format.dart';

/// Uses a user-provided Calendarific key or a configured backend proxy.
class HolidaySync extends ChangeNotifier {
  static const configuredEndpoint = String.fromEnvironment(
    'AGENDA_HOLIDAY_ENDPOINT',
  );
  static final instance = HolidaySync();
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'agenda_calendarific_key_v1';
  final http.Client _client;
  final String endpoint;
  final Map<int, Future<HolidaySnapshot?>> _pending = {};
  final Map<int, (DateTime, HolidaySnapshot?)> _recent = {};
  int _generation = 0;

  HolidaySync({http.Client? client, this.endpoint = configuredEndpoint})
    : _client = client ?? http.Client();

  Future<bool> hasApiKey() async =>
      (await _storage.read(key: _keyName))?.isNotEmpty == true;

  /// Validate before replacing a working key. No credential or request URL is logged.
  Future<void> saveApiKey(String value) async {
    final key = value.trim();
    if (key.isEmpty || key.length > 256 || key.contains(RegExp(r'\s'))) {
      throw const FormatException('مفتاح غير صالح');
    }
    final year = DateTime.now().year;
    final response = await _client
        .get(_calendarificUri(year, key))
        .timeout(const Duration(seconds: 8));
    final snapshot =
        response.statusCode == 200 && response.bodyBytes.length <= 1024 * 1024
        ? HolidaySnapshot.fromResponse(response.body, year, DateTime.now())
        : null;
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 1024 * 1024 ||
        snapshot == null) {
      throw const FormatException('تعذر التحقق من المفتاح أو بيانات الخدمة');
    }
    await _storage.write(key: _keyName, value: key);
    try {
      await _storage.write(
        key: 'agenda_holidays_${year}_v1',
        value: snapshot.toCache(),
      );
    } catch (_) {
      // Saving the key succeeded even if the optional local cache failed.
    }
    _reset();
  }

  Future<void> removeApiKey() async {
    await _storage.delete(key: _keyName);
    _reset();
  }

  Uri _calendarificUri(int year, String key) => Uri.https(
    'calendarific.com',
    '/api/v2/holidays',
    {'api_key': key, 'country': 'EG', 'year': '$year', 'type': 'national'},
  );

  void _reset() {
    _generation++;
    _recent.clear();
    _pending.clear();
    notifyListeners();
  }

  Future<HolidaySnapshot?> forYear(int year) {
    final recent = _recent[year];
    if (recent != null &&
        DateTime.now().difference(recent.$1) < const Duration(hours: 1)) {
      return Future.value(recent.$2);
    }
    final generation = _generation;
    return _pending.putIfAbsent(year, () async {
      try {
        final value = await _load(year, generation);
        if (generation == _generation) _recent[year] = (DateTime.now(), value);
        return value;
      } finally {
        if (generation == _generation) _pending.remove(year);
      }
    });
  }

  Future<HolidaySnapshot?> _load(int year, int generation) async {
    if (year < 1900 || year > 2200) return null;
    final cacheKey = 'agenda_holidays_${year}_v1';
    HolidaySnapshot? cached;
    try {
      final data = await _storage.read(key: cacheKey);
      if (data != null) cached = HolidaySnapshot.fromCache(data, year);
    } catch (_) {
      // A storage failure must not prevent opening the agenda.
    }
    String? apiKey;
    try {
      apiKey = await _storage.read(key: _keyName);
    } catch (_) {
      return cached;
    }
    final url = Uri.tryParse(endpoint);
    final proxyValid =
        url != null &&
        url.scheme == 'https' &&
        url.host.isNotEmpty &&
        url.userInfo.isEmpty &&
        url.host.toLowerCase() != 'calendarific.com' &&
        !url.queryParameters.keys.any((key) => key.toLowerCase() == 'api_key');
    if ((apiKey == null || apiKey.isEmpty) && !proxyValid) {
      return cached;
    }
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(hours: 24)) {
      return cached;
    }
    try {
      final uri = apiKey != null && apiKey.isNotEmpty
          ? _calendarificUri(year, apiKey)
          : url!.replace(
              queryParameters: {
                ...url.queryParameters,
                'country': 'EG',
                'year': '$year',
                'type': 'national',
              },
            );
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
      if (generation != _generation) return cached;
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
