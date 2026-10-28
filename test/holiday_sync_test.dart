import 'dart:convert';

import 'package:agenda/core/utils/holiday_sync.dart';
import 'package:agenda/core/widgets/holiday_status.dart';
import 'package:agenda/features/settings/presentation/screens/holiday_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('fetches Egypt via the proxy and caches valid results', () async {
    Uri? requested;
    final service = HolidaySync(
      endpoint: 'https://example.com/holidays',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'meta': {'code': 200},
            'response': {
              'holidays': [
                {
                  'name': 'Holiday observed',
                  'date': {'iso': '2027-07-01'},
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    final result = await service.forYear(2027);
    expect(requested!.queryParameters, containsPair('country', 'EG'));
    expect(requested!.queryParameters, containsPair('year', '2027'));
    expect(requested!.queryParameters, containsPair('type', 'national'));
    expect(result!.holidays['2027-07-01'], 'Holiday observed');
    expect(
      await const FlutterSecureStorage().read(key: 'agenda_holidays_2027_v1'),
      isNotNull,
    );
  });

  test(
    'preserves stale cache when the response is malformed or unavailable',
    () async {
      final previous = HolidaySnapshot(DateTime(2020), {
        '2027-07-01': 'Old holiday',
      });
      await const FlutterSecureStorage().write(
        key: 'agenda_holidays_2027_v1',
        value: previous.toCache(),
      );
      final service = HolidaySync(
        endpoint: 'https://example.com/holidays',
        client: MockClient((_) async => http.Response('invalid', 200)),
      );
      expect(
        (await service.forYear(2027))!.holidays['2027-07-01'],
        'Old holiday',
      );
      final cached = await const FlutterSecureStorage().read(
        key: 'agenda_holidays_2027_v1',
      );
      expect(
        HolidaySnapshot.fromCache(cached!, 2027)!.holidays['2027-07-01'],
        'Old holiday',
      );
    },
  );

  test('rejects insecure URLs and API keys in the client endpoint', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    await HolidaySync(
      endpoint: 'https://example.com/?api_key=placeholder',
      client: client,
    ).forYear(2027);
    await HolidaySync(
      endpoint: 'http://example.com',
      client: client,
    ).forYear(2027);
    expect(requests, 0);
  });

  test('validates and stores a user key, then uses it for Egypt without replacing it on failure', () async {
    var deny = false;
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (deny) return http.Response('{}', 401);
      final year = request.url.queryParameters['year']!;
      return http.Response(
        jsonEncode({
          'meta': {'code': 200},
          'response': {
            'holidays': [
              {
                'name': 'Holiday',
                'date': {'iso': '$year-07-01'},
              },
            ],
          },
        }),
        200,
      );
    });
    final service = HolidaySync(client: client);
    expect(await service.hasApiKey(), isFalse);
    await service.saveApiKey('local-test-key');
    expect(await service.hasApiKey(), isTrue);
    expect(requests.first.host, 'calendarific.com');
    expect(requests.first.queryParameters['country'], 'EG');
    expect((await service.forYear(2027))!.holidays['2027-07-01'], 'Holiday');
    deny = true;
    await expectLater(service.saveApiKey('invalid-key'), throwsFormatException);
    expect(
      await const FlutterSecureStorage().read(
        key: 'agenda_calendarific_key_v1',
      ),
      'local-test-key',
    );
    await service.removeApiKey();
    expect(await service.hasApiKey(), isFalse);
  });

  testWidgets('external dates are presented as unconfirmed', (tester) async {
    final service = HolidaySync(
      endpoint: 'https://example.com/holidays',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'meta': {'code': 200},
            'response': {
              'holidays': [
                {
                  'name': 'Estimated holiday',
                  'date': {'iso': '2027-07-01'},
                },
              ],
            },
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HolidayStatus(date: DateTime(2027, 7, 1), service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مناسبة محتملة — تحقق من القرار'), findsOneWidget);
    expect(find.text('Estimated holiday'), findsOneWidget);
    expect(find.text('إجازة رسمية معلنة'), findsNothing);
  });

  testWidgets('settings validates and saves a key without displaying it afterward', (tester) async {
    final service = HolidaySync(client: MockClient((request) async {
      final year = request.url.queryParameters['year']!;
      return http.Response(jsonEncode({
        'meta': {'code': 200},
        'response': {'holidays': [
          {'name': 'Holiday', 'date': {'iso': '$year-07-01'}},
        ]},
      }), 200);
    }));
    await tester.pumpWidget(MaterialApp(home: HolidaySettingsScreen(service: service)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'example-private-key');
    await tester.tap(find.text('التحقق والحفظ'));
    await tester.pumpAndSettle();
    expect(find.text('مفتاح Calendarific محفوظ على هذا الجهاز.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(await service.hasApiKey(), isTrue);
  });
}
