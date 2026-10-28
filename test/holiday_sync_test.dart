import 'dart:convert';

import 'package:agenda/core/utils/holiday_sync.dart';
import 'package:agenda/core/widgets/holiday_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('fetches Egyptian holidays from Calendarific and caches valid results', () async {
    Uri? requested;
    final service = HolidaySync(
      apiKey: 'test-key',
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
    expect(requested!.host, 'calendarific.com');
    expect(requested!.queryParameters, containsPair('api_key', 'test-key'));
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
        apiKey: 'test-key',
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

  test('does not request the service when no build key is configured', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    await HolidaySync(apiKey: '', client: client).forYear(2027);
    expect(requests, 0);
  });

  testWidgets('external dates are presented as unconfirmed', (tester) async {
    final service = HolidaySync(
      apiKey: 'test-key',
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


}
